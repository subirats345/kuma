---
name: kuma-pdf
description: Use when creating, editing, rendering, or visually checking Markdown-to-PDF documents with Kuma on macOS. Covers Kuma-compatible Markdown, the kuma CLI, watch mode, preview PNG generation, local images, code blocks, and layout checks.
metadata:
  short-description: Render calm PDFs with Kuma
---

# Kuma PDF

Use Kuma when the user wants a quiet, native macOS PDF from a simple Markdown source.

## Workflow

1. Create or edit a `.md` file using Kuma's supported subset.
2. Render it with `kuma input.md output.pdf`, or use `kuma input.md --open` when the user wants to inspect the result.
3. For iteration, run `kuma watch input.md output.pdf`.
4. When visual verification matters, generate a first-page PNG preview:

```sh
skills/kuma-pdf/scripts/render-preview.sh input.md output.pdf .build/previews
```

5. Inspect the PDF or preview for heading spacing, list alignment, image scale, code blocks, and broken local image paths.

## Markdown Shape

Prefer:

- `#` through `######` headings
- short paragraphs
- unordered lists with `-` or `*`
- local images with `![caption](path/to/image.png)`
- fenced code blocks
- plain URLs and email addresses

Avoid remote images, HTML, tables, footnotes, nested lists, and Markdown extensions unless the current Kuma renderer explicitly supports them. Unsupported syntax renders as plain text.

## Layout Notes

- Keep headings close to the content they introduce; remove unnecessary blank lines in the Markdown before changing renderer code.
- Use local image paths relative to the Markdown file when possible.
- Wide images are scaled to the page body width.
- Long images may be constrained by page height, so verify the preview when images are important.
- Keep bullets concise; Kuma is tuned for calm printable documents, not dense outlines.

## Useful Commands

```sh
kuma
kuma init note.md
kuma note.md note.pdf
kuma note.md --open
kuma watch note.md note.pdf --open
skills/kuma-pdf/scripts/render-preview.sh note.md .build/note.pdf .build/previews
```

Report both the PDF path and any preview PNG path in the final answer.
