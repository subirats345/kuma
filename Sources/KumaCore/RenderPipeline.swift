import CoreFoundation
import CoreGraphics
import CoreText
import Foundation

func renderMarkdownPDF(inputURL: URL, outputURL: URL) throws {
    try validateRenderPaths(inputURL: inputURL, outputURL: outputURL)

    let markdown: String
    do {
        markdown = try String(contentsOf: inputURL, encoding: .utf8)
    } catch {
        throw KumaError.cannotReadInput(inputURL, error)
    }

    let blocks = parseMarkdown(markdown)
    do {
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    } catch {
        throw KumaError.cannotCreateOutputDirectory(outputURL.deletingLastPathComponent(), error)
    }

    let bodyFont = font(named: defaultBodyFontName, size: 11)
    let headingFont = font(named: defaultHeadingFontName, size: 18)
    let codeFont = font(named: defaultCodeFontName, size: 9.5)

    guard let consumer = CGDataConsumer(url: outputURL as CFURL) else {
        throw KumaError.cannotCreatePDF(outputURL)
    }

    var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
    guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
        throw KumaError.cannotCreatePDFContext
    }

    var renderer = Renderer(
        context: context,
        inputDirectory: inputURL.deletingLastPathComponent(),
        bodyFont: bodyFont,
        headingFont: headingFont,
        codeFont: codeFont
    )

    renderer.beginPage(startY: firstPageStartY)
    var previous: Block?
    for block in blocks {
        switch block {
        case .heading(let level, let text):
            renderer.drawHeading(level: level, text: text, previous: previous)
        case .paragraph(let text):
            renderer.drawParagraph(text, previous: previous)
        case .listItem(let marker, let level, let text):
            renderer.drawListItem(marker: marker, level: level, text: text, previous: previous)
        case .image(let alt, let path):
            renderer.drawImage(alt: alt, path: path, previous: previous)
        case .code(let language, let text):
            renderer.drawCode(language: language, text: text, previous: previous)
        case .blockquote(let text):
            renderer.drawBlockquote(text, previous: previous)
        case .horizontalRule:
            renderer.drawHorizontalRule(previous: previous)
        case .table(let table):
            renderer.drawTable(table, previous: previous)
        }
        previous = block
    }
    renderer.endPage()
    context.closePDF()
}
