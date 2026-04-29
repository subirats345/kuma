<p align="center">
  <img src="Assets/kuma-mascot.svg" width="156" alt="Kuma mascot">
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
  <img src="Assets/screenshots/shakespeare-sonnet-18.png" width="260" alt="Kuma Shakespeare PDF screenshot">
  <img src="Assets/screenshots/dickinson-hope.png" width="260" alt="Kuma Dickinson PDF screenshot">
</p>

Kuma is deliberately small: plain Markdown in, quiet A4 PDF out. It uses CoreText and Quartz directly, so there is no browser, HTML layer, server runtime, or template engine involved.

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
```

If no output path is provided, Kuma writes a `.pdf` next to the input Markdown file.

The short alias is installed as `ku`:

```sh
ku Examples/basic.md
```

## Examples

The examples are intentionally made from public-domain texts, so the repository stays easy to share.

| Source | Rendered PDF preview |
| --- | --- |
| [`Examples/basic.md`](Examples/basic.md) | <img src="Assets/screenshots/basic.png" width="220" alt="Basic example preview"> |
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
