<p align="center">
  <img src="Assets/kuma-mascot.png" width="620" alt="Kuma mascot">
</p>

<h1 align="center">Kuma</h1>

<p align="center">
  A tiny native Markdown-to-PDF renderer for macOS.
</p>

<p align="center">
  <code>brew install subirats345/tap/kuma</code>
</p>

<p align="center">
  <img src="Assets/screenshots/basic.png" width="260" alt="Kuma basic example PDF screenshot">
  <img src="Assets/screenshots/technical-note.png" width="260" alt="Kuma technical PDF screenshot">
  <img src="Assets/screenshots/moby-dick-loomings.png" width="260" alt="Kuma Moby-Dick PDF screenshot">
</p>

Kuma is deliberately small: plain Markdown in, quiet A4 PDF out. It uses CoreText, ImageIO, and Quartz directly, so there is no browser, HTML layer, server runtime, or template engine involved.

The goal is not to support every Markdown extension. The goal is to make simple documents feel calm, native, and printable.

## Install

With Homebrew:

```sh
brew install subirats345/tap/kuma
```

From source:

```sh
git clone https://github.com/subirats345/kuma.git
cd kuma
./Scripts/install-local.sh
```

Or build it manually:

```sh
swift build -c release
install -m 755 .build/release/kuma ~/.local/bin/kuma
```

## Usage

```sh
kuma input.md
kuma input.md output.pdf
kuma input.md -o output.pdf
kuma input.md --theme sumi
kuma --list-themes
```

If no output path is provided, Kuma writes a `.pdf` next to the input Markdown file.

The short alias is installed as `ku`:

```sh
ku Examples/basic.md
```

## Themes

Kuma ships with a tiny set of built-in themes. They change the page tint, text color, accent marks, captions, and code block colors while keeping the same quiet layout.

```sh
kuma Examples/technical-note.md --theme paper
kuma Examples/technical-note.md --theme sumi
KUMA_THEME=aizome kuma Examples/technical-note.md
```

Available themes:

| Theme | Preview |
| --- | --- |
| `paper` | <img src="Assets/screenshots/theme-paper.png" width="180" alt="Paper theme preview"> |
| `sumi` | <img src="Assets/screenshots/theme-sumi.png" width="180" alt="Sumi theme preview"> |
| `aka` | <img src="Assets/screenshots/theme-aka.png" width="180" alt="Aka theme preview"> |
| `mori` | <img src="Assets/screenshots/theme-mori.png" width="180" alt="Mori theme preview"> |
| `aizome` | <img src="Assets/screenshots/theme-aizome.png" width="180" alt="Aizome theme preview"> |

## Examples

The examples are intentionally made from public-domain texts, so the repository stays easy to share.

| Source | Rendered PDF preview |
| --- | --- |
| [`Examples/basic.md`](Examples/basic.md) | <img src="Assets/screenshots/basic.png" width="220" alt="Basic example preview"> |
| [`Examples/technical-note.md`](Examples/technical-note.md) | <img src="Assets/screenshots/technical-note.png" width="220" alt="Technical note preview"> |
| [`Examples/moby-dick-loomings.md`](Examples/moby-dick-loomings.md) | <img src="Assets/screenshots/moby-dick-loomings.png" width="220" alt="Moby-Dick preview"> |
| [`Examples/shakespeare-sonnet-18.md`](Examples/shakespeare-sonnet-18.md) | <img src="Assets/screenshots/shakespeare-sonnet-18.png" width="220" alt="Shakespeare Sonnet 18 preview"> |
| [`Examples/dickinson-hope.md`](Examples/dickinson-hope.md) | <img src="Assets/screenshots/dickinson-hope.png" width="220" alt="Emily Dickinson Hope preview"> |
| [`Examples/cervantes-quixote.md`](Examples/cervantes-quixote.md) | <img src="Assets/screenshots/cervantes-quixote.png" width="220" alt="Don Quixote preview"> |
| [`Examples/aurelius-meditations.md`](Examples/aurelius-meditations.md) | <img src="Assets/screenshots/aurelius-meditations.png" width="220" alt="Marcus Aurelius preview"> |

Render all examples locally:

```sh
mkdir -p .build/examples
for md in Examples/*.md; do
  kuma "$md" ".build/examples/$(basename "$md" .md).pdf"
done
```

## Markdown Support

Kuma currently supports the small subset needed for calm documents:

- `#` through `######` headings
- paragraphs
- unordered lists with `-` or `*`
- local images with `![caption](path/to/image.png)`
- fenced code blocks
- automatic accent coloring for emails and `http` or `https` URLs

Unsupported Markdown is treated as plain text. That keeps the renderer predictable while the project is still small.

## Fonts

By default, Kuma uses installed macOS fonts:

- body: `AvenirNext-Regular`
- headings: `AvenirNext-DemiBold`

You can use your own local fonts without committing or redistributing them:

```sh
KUMA_FONT_DIR="$HOME/Library/Fonts" \
KUMA_BODY_FONT="YourBodyFont-Regular" \
KUMA_HEADING_FONT="YourHeadingFont-Semibold" \
KUMA_CODE_FONT="YourMonoFont-Regular" \
kuma Examples/basic.md output.pdf
```

`KUMA_FONT_DIR` registers `.otf`, `.ttf`, and `.ttc` files for the current process.

## Development

```sh
swift build
swift run kuma Examples/basic.md .build/kuma-example.pdf
swift build -c release
```

Kuma is dependency-free. The only requirement is macOS with SwiftPM.
