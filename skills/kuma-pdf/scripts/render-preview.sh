#!/usr/bin/env sh
set -eu

usage() {
  echo "Usage: render-preview.sh input.md [output.pdf] [preview-dir]" >&2
}

if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
  usage
  exit 64
fi

input=$1

if [ ! -f "$input" ]; then
  echo "Input Markdown not found: $input" >&2
  exit 66
fi

if [ "$#" -ge 2 ]; then
  output=$2
else
  input_dir=$(dirname "$input")
  input_base=$(basename "$input")
  output="$input_dir/${input_base%.*}.pdf"
fi

if [ "$#" -ge 3 ]; then
  preview_dir=$3
else
  preview_dir=$(dirname "$output")
fi

mkdir -p "$(dirname "$output")" "$preview_dir"

kuma "$input" "$output"

if [ ! -s "$output" ]; then
  echo "PDF was not created: $output" >&2
  exit 70
fi

echo "pdf=$output"

if [ "${KUMA_SKIP_PREVIEW:-}" = "1" ]; then
  exit 0
fi

preview_path="$preview_dir/$(basename "$output").png"

if command -v qlmanage >/dev/null 2>&1; then
  rm -f "$preview_path"
  if qlmanage -t -s "${KUMA_PREVIEW_SIZE:-1600}" -o "$preview_dir" "$output" >/dev/null 2>&1 && [ -s "$preview_path" ]; then
    echo "preview=$preview_path"
    exit 0
  fi
  echo "warning: qlmanage preview generation failed; PDF render still succeeded" >&2
else
  echo "warning: qlmanage not found; preview skipped" >&2
fi
