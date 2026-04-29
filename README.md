# Kuma

Kuma is a tiny native Markdown-to-PDF renderer for macOS.

It is intentionally small: plain Markdown in, quiet A4 PDF out. It uses CoreText and Quartz directly, so there is no browser, HTML layer, or external runtime involved.

## Install

With Homebrew:

```sh
brew install subirats345/tap/kuma
```

Build and install the CLI into `~/.local/bin`:

```sh
./Scripts/install-local.sh
```

Or build it manually:

```sh
swift build -c release
install -m 755 .build/release/kuma ~/.local/bin/kuma
```

## Usage

```sh
kuma Examples/basic.md
kuma Examples/basic.md output.pdf
kuma Examples/basic.md -o output.pdf
```

If no output path is provided, Kuma writes a `.pdf` next to the input Markdown file.

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

The project is deliberately dependency-free. The only requirement is macOS with SwiftPM.
