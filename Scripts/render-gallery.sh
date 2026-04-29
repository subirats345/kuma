#!/usr/bin/env sh
set -eu

usage() {
  cat <<'USAGE'
Usage: Scripts/render-gallery.sh [--update-screenshots] [output-dir]

Render every Markdown file in Examples/ into a local PDF gallery.

Options:
  --update-screenshots  Copy generated previews into Assets/screenshots/
  -h, --help            Show this help

Environment:
  KUMA_BIN              Path to a Kuma binary
  KUMA_SKIP_PREVIEW=1   Render PDFs only
  KUMA_REQUIRE_PREVIEW=1
                        Fail when preview generation is unavailable
  KUMA_PREVIEW_SIZE     Preview width in pixels, default 1600
USAGE
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
output_dir=
update_screenshots=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --update-screenshots)
      update_screenshots=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 64
      ;;
    *)
      if [ -n "$output_dir" ]; then
        echo "Only one output directory may be provided." >&2
        usage >&2
        exit 64
      fi
      output_dir=$1
      ;;
  esac
  shift
done

output_dir=${output_dir:-"$root_dir/.build/gallery"}
pdf_dir="$output_dir/pdfs"
preview_dir="$output_dir/previews"
screenshots_dir="$root_dir/Assets/screenshots"
index_path="$output_dir/index.html"
summary_path="$output_dir/summary.txt"
examples_dir="$root_dir/Examples"

if [ -n "${KUMA_BIN:-}" ]; then
  kuma_bin=$KUMA_BIN
elif [ -x "$root_dir/.build/debug/kuma" ]; then
  kuma_bin="$root_dir/.build/debug/kuma"
elif command -v kuma >/dev/null 2>&1; then
  kuma_bin=$(command -v kuma)
else
  (cd "$root_dir" && swift build)
  kuma_bin="$root_dir/.build/debug/kuma"
fi

if [ ! -x "$kuma_bin" ]; then
  echo "Kuma binary is not executable: $kuma_bin" >&2
  exit 69
fi

if [ "$update_screenshots" -eq 1 ] && [ "${KUMA_SKIP_PREVIEW:-}" = "1" ]; then
  echo "--update-screenshots requires preview generation." >&2
  exit 64
fi

mkdir -p "$pdf_dir" "$preview_dir" "$screenshots_dir"
find "$pdf_dir" -type f -name '*.pdf' -delete
find "$preview_dir" -type f -name '*.png' -delete

html_escape() {
  printf '%s' "$1" | sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g' \
    -e 's/"/\&quot;/g'
}

render_preview() {
  pdf_path=$1
  name=$2
  preview_path="$preview_dir/$name.png"

  if [ "${KUMA_SKIP_PREVIEW:-}" = "1" ]; then
    return 0
  fi

  if ! command -v qlmanage >/dev/null 2>&1; then
    if [ "${KUMA_REQUIRE_PREVIEW:-}" = "1" ]; then
      echo "qlmanage is required for previews but was not found." >&2
      exit 69
    fi
    echo "warning: qlmanage not found; previews skipped" >&2
    return 0
  fi

  raw_preview="$preview_dir/$(basename "$pdf_path").png"
  rm -f "$raw_preview" "$preview_path"

  if qlmanage -t -s "${KUMA_PREVIEW_SIZE:-1600}" -o "$preview_dir" "$pdf_path" >/dev/null 2>&1 && [ -s "$raw_preview" ]; then
    mv "$raw_preview" "$preview_path"
    return 0
  fi

  if [ "${KUMA_REQUIRE_PREVIEW:-}" = "1" ]; then
    echo "Preview generation failed for $pdf_path" >&2
    exit 70
  fi

  echo "warning: preview generation failed for $pdf_path" >&2
}

cat > "$index_path" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Kuma Visual Gallery</title>
  <style>
    :root {
      color-scheme: light;
      --text: #111111;
      --muted: #6f6f6f;
      --line: #dedede;
      --paper: #ffffff;
      --background: #f4f2ee;
      --accent: #dd4c4f;
    }

    * {
      box-sizing: border-box;
    }

    body {
      margin: 0;
      background: var(--background);
      color: var(--text);
      font-family: Avenir Next, Avenir, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif;
    }

    main {
      max-width: 1180px;
      margin: 0 auto;
      padding: 44px 28px 64px;
    }

    header {
      display: flex;
      align-items: flex-end;
      justify-content: space-between;
      gap: 20px;
      margin-bottom: 28px;
      border-bottom: 1px solid var(--line);
      padding-bottom: 18px;
    }

    h1 {
      margin: 0;
      font-size: 34px;
      line-height: 1.05;
      letter-spacing: 0;
    }

    .meta {
      margin: 8px 0 0;
      color: var(--muted);
      font-size: 14px;
    }

    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
      gap: 20px;
    }

    article {
      background: var(--paper);
      border: 1px solid var(--line);
      border-radius: 8px;
      overflow: hidden;
    }

    article img {
      display: block;
      width: 100%;
      height: auto;
      background: #ffffff;
    }

    .body {
      padding: 14px 16px 16px;
    }

    h2 {
      margin: 0 0 8px;
      font-size: 17px;
      line-height: 1.25;
      letter-spacing: 0;
    }

    a {
      color: var(--accent);
      text-decoration: none;
    }

    a:hover {
      text-decoration: underline;
    }

    .missing {
      display: grid;
      min-height: 320px;
      margin: 0;
      place-items: center;
      color: var(--muted);
      border-bottom: 1px solid var(--line);
      background: #fafafa;
    }
  </style>
</head>
<body>
  <main>
    <header>
      <div>
        <h1>Kuma Visual Gallery</h1>
        <p class="meta">Generated from Examples/*.md</p>
      </div>
    </header>
    <section class="grid">
HTML

: > "$summary_path"
count=0

for md_path in "$examples_dir"/*.md; do
  [ -e "$md_path" ] || continue

  name=$(basename "$md_path" .md)
  pdf_path="$pdf_dir/$name.pdf"
  preview_path="$preview_dir/$name.png"

  "$kuma_bin" "$md_path" "$pdf_path" >/dev/null
  test -s "$pdf_path"

  render_preview "$pdf_path" "$name"

  if [ "$update_screenshots" -eq 1 ] && [ -s "$preview_path" ]; then
    cp "$preview_path" "$screenshots_dir/$name.png"
  fi

  escaped_name=$(html_escape "$name")
  pdf_rel="pdfs/$name.pdf"
  preview_rel="previews/$name.png"

  if [ -s "$preview_path" ]; then
    media="<a href=\"$pdf_rel\"><img src=\"$preview_rel\" alt=\"$escaped_name PDF preview\"></a>"
  else
    media="<p class=\"missing\">Preview skipped</p>"
  fi

  cat >> "$index_path" <<HTML
      <article>
        $media
        <div class="body">
          <h2>$escaped_name</h2>
          <a href="$pdf_rel">Open PDF</a>
        </div>
      </article>
HTML

  {
    echo "source=$md_path"
    echo "pdf=$pdf_path"
    if [ -s "$preview_path" ]; then
      echo "preview=$preview_path"
    fi
    echo
  } >> "$summary_path"

  count=$((count + 1))
done

cat >> "$index_path" <<'HTML'
    </section>
  </main>
</body>
</html>
HTML

if [ "$count" -eq 0 ]; then
  echo "No Markdown examples found in $examples_dir" >&2
  exit 66
fi

echo "Rendered $count examples"
echo "gallery=$index_path"
echo "pdfs=$pdf_dir"
echo "previews=$preview_dir"
echo "summary=$summary_path"
