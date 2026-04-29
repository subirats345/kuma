# Markdown Features

Kuma now supports **bold**, *italic*, ***combined emphasis***, `inline code`, ~~strikethrough~~, [named links](https://github.com/subirats345/kuma), raw URLs such as https://example.com, and emails such as hello@example.com.

Hard line breaks can be written with a trailing backslash.\
This line starts immediately below the previous one without opening a new paragraph.

## Blockquotes

> A quote should feel quieter than the main text.
> It keeps the same rhythm, but uses a soft rule and muted text.

## Ordered Lists

1. Parse the Markdown source.
2. Build a small sequence of document blocks.
3. Render those blocks into a native Quartz PDF.

## Nested and Task Lists

- Keep the renderer small.
  - Support practical Markdown first.
  - Keep visual decisions opinionated.
- Track follow-up work.
  - [x] Inline styling
  - [x] Blockquotes
  - [x] Tables
  - [ ] Math and diagrams

---

## Tables

| Feature | Syntax | Status |
| --- | --- | --- |
| Bold | `**text**` | Done |
| Italic | `*text*` | Done |
| Link | `[label](url)` | Done |
| Task | `- [x] item` | Done |

## Escapes

Use backslashes when literal Markdown markers should remain visible: \*not italic\*, \`not code\`, and \[not a link\](https://example.com).
