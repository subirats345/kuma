import CoreFoundation
import CoreGraphics
import CoreText
import Foundation
import ImageIO

let pageWidth: CGFloat = 595
let pageHeight: CGFloat = 842
let leftX: CGFloat = 45
let headingX: CGFloat = 46
let bodyWidth: CGFloat = 505
let bulletTextX: CGFloat = 70
let bulletWidth: CGFloat = 480
let bulletDotX: CGFloat = 53
let bodyLineHeight: CGFloat = 20
let pageStartY: CGFloat = 64
let firstPageStartY: CGFloat = 72
let maxBaselineY: CGFloat = 790
let accentColor = CGColor(red: 0.8666667, green: 0.2980392, blue: 0.3098039, alpha: 1)
let blackColor = CGColor(gray: 0, alpha: 1)
let appName = "Kuma"
let appVersion = "0.2.0"
let defaultBodyFontName = "AvenirNext-Regular"
let defaultHeadingFontName = "AvenirNext-DemiBold"
let defaultCodeFontName = "Menlo-Regular"

enum Block {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullet(String)
    case image(alt: String, path: String)
    case code(language: String?, text: String)
}

struct Renderer {
    let context: CGContext
    let inputDirectory: URL
    let bodyFont: CTFont
    let headingFont: CTFont
    let codeFont: CTFont
    var y: CGFloat = firstPageStartY
    var pageNumber = 0

    mutating func beginPage(startY: CGFloat) {
        let box = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        context.beginPDFPage([kCGPDFContextMediaBox: box] as CFDictionary)
        context.textMatrix = .identity
        context.setShouldAntialias(true)
        context.setShouldSmoothFonts(true)
        context.setAllowsFontSmoothing(true)
        context.setAllowsFontSubpixelPositioning(true)
        y = startY
        pageNumber += 1
    }

    func endPage() {
        context.endPDFPage()
    }

    mutating func newPage() {
        endPage()
        beginPage(startY: pageStartY)
    }

    func drawLine(_ line: CTLine, x: CGFloat, baselineY: CGFloat) {
        context.textPosition = CGPoint(x: x, y: pageHeight - baselineY)
        CTLineDraw(line, context)
    }

    func fillRect(x: CGFloat, topY: CGFloat, width: CGFloat, height: CGFloat, color: CGColor) {
        context.saveGState()
        context.setFillColor(color)
        context.fill(CGRect(x: x, y: pageHeight - topY - height, width: width, height: height))
        context.restoreGState()
    }

    func strokeRect(x: CGFloat, topY: CGFloat, width: CGFloat, height: CGFloat, color: CGColor, lineWidth: CGFloat) {
        context.saveGState()
        context.setStrokeColor(color)
        context.setLineWidth(lineWidth)
        context.stroke(CGRect(x: x, y: pageHeight - topY - height, width: width, height: height))
        context.restoreGState()
    }

    mutating func drawWrapped(_ attributed: NSAttributedString, x: CGFloat, width: CGFloat, lineHeight: CGFloat) {
        let typesetter = CTTypesetterCreateWithAttributedString(attributed)
        let string = attributed.string as NSString
        var start = 0
        let length = attributed.length

        while start < length {
            while start < length {
                let char = string.character(at: start)
                if char == 32 || char == 10 || char == 9 {
                    start += 1
                } else {
                    break
                }
            }
            if start >= length { break }

            if y > maxBaselineY {
                newPage()
            }

            let count = CTTypesetterSuggestLineBreak(typesetter, start, Double(width))
            let line = CTTypesetterCreateLine(typesetter, CFRange(location: start, length: count))
            drawLine(line, x: x, baselineY: y)
            y += lineHeight
            start += count
        }
    }

    mutating func drawHeading(level: Int, text: String, previous: Block?) {
        if case .heading(1, _) = previous {
            y += 0
        } else if previous != nil {
            if level == 2 {
                y += 34
            } else if level == 3 {
                if case .heading(2, _) = previous {
                    y += 7
                } else {
                    y += 27
                }
            }
        }

        if y > maxBaselineY - 40 {
            newPage()
        }

        let size: CGFloat
        let nextGap: CGFloat
        switch level {
        case 1:
            size = 22
            nextGap = 42
        case 2:
            size = 18
            nextGap = 39
        default:
            size = 14
            nextGap = 22
        }

        let font = CTFontCreateCopyWithAttributes(headingFont, size, nil, nil)
        let attr = NSAttributedString(string: text, attributes: [
            kCTFontAttributeName as NSAttributedString.Key: font,
            kCTForegroundColorAttributeName as NSAttributedString.Key: blackColor
        ])
        let line = CTLineCreateWithAttributedString(attr)
        drawLine(line, x: headingX, baselineY: y)
        y += nextGap
    }

    mutating func drawParagraph(_ text: String, previous: Block?) {
        let attr = makeInlineAttributed(text)
        drawWrapped(attr, x: leftX, width: bodyWidth, lineHeight: bodyLineHeight)
    }

    mutating func drawBullet(_ text: String, previous: Block?) {
        if case .paragraph = previous {
            y += 20
        }

        let attr = makeInlineAttributed(text)
        let typesetter = CTTypesetterCreateWithAttributedString(attr)
        let string = attr.string as NSString
        var start = 0
        let length = attr.length
        var firstLine = true

        while start < length {
            while start < length {
                let char = string.character(at: start)
                if char == 32 || char == 10 || char == 9 {
                    start += 1
                } else {
                    break
                }
            }
            if start >= length { break }

            if y > maxBaselineY {
                newPage()
            }

            if firstLine {
                drawBulletDot(baselineY: y)
                firstLine = false
            }

            let count = CTTypesetterSuggestLineBreak(typesetter, start, Double(bulletWidth))
            let line = CTTypesetterCreateLine(typesetter, CFRange(location: start, length: count))
            drawLine(line, x: bulletTextX, baselineY: y)
            y += bodyLineHeight
            start += count
        }
    }

    func drawBulletDot(baselineY: CGFloat) {
        context.saveGState()
        context.setFillColor(accentColor)
        let radius: CGFloat = 2.45
        let centerY = baselineY - (CTFontGetCapHeight(bodyFont) / 2)
        let center = CGPoint(x: bulletDotX, y: pageHeight - centerY)
        context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.restoreGState()
    }

    mutating func drawImage(alt: String, path: String, previous: Block?) {
        if previous != nil {
            y += 18
        }

        guard let image = loadImage(path: path) else {
            drawParagraph("[image not found: \(path)]", previous: previous)
            return
        }

        let sourceWidth = CGFloat(image.width)
        let sourceHeight = CGFloat(image.height)
        guard sourceWidth > 0, sourceHeight > 0 else { return }

        let maxImageHeight: CGFloat = 300
        let scale = min(bodyWidth / sourceWidth, maxImageHeight / sourceHeight, 1)
        let drawWidth = sourceWidth * scale
        let drawHeight = sourceHeight * scale

        if y + drawHeight > maxBaselineY {
            newPage()
        }

        let x = leftX + ((bodyWidth - drawWidth) / 2)
        let rect = CGRect(x: x, y: pageHeight - y - drawHeight, width: drawWidth, height: drawHeight)

        context.saveGState()
        context.interpolationQuality = .high
        context.draw(image, in: rect)
        context.restoreGState()

        y += drawHeight + 20

        if !alt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let captionFont = CTFontCreateCopyWithAttributes(bodyFont, 9, nil, nil)
            let caption = NSAttributedString(string: alt, attributes: [
                kCTFontAttributeName as NSAttributedString.Key: captionFont,
                kCTForegroundColorAttributeName as NSAttributedString.Key: CGColor(gray: 0.35, alpha: 1)
            ])
            drawWrapped(caption, x: leftX, width: bodyWidth, lineHeight: 14)
            y += 8
        }
    }

    mutating func drawCode(language: String?, text: String, previous: Block?) {
        if previous != nil {
            y += 16
        }

        let padding: CGFloat = 10
        let codeLineHeight: CGFloat = 15
        let codeWidth = bodyWidth
        let innerWidth = codeWidth - (padding * 2)
        let lines = makeCodeLines(text, width: innerWidth)
        var index = 0

        while index < lines.count {
            if y > maxBaselineY - 45 {
                newPage()
            }

            let available = maxBaselineY - y
            let maxLines = max(1, Int((available - (padding * 2)) / codeLineHeight))
            let count = min(maxLines, lines.count - index)
            let boxHeight = CGFloat(count) * codeLineHeight + (padding * 2)

            fillRect(x: leftX, topY: y, width: codeWidth, height: boxHeight, color: CGColor(red: 0.965, green: 0.955, blue: 0.935, alpha: 1))
            strokeRect(x: leftX, topY: y, width: codeWidth, height: boxHeight, color: CGColor(red: 0.88, green: 0.86, blue: 0.82, alpha: 1), lineWidth: 0.8)

            var baseline = y + padding + 10
            for line in lines[index..<(index + count)] {
                drawLine(line, x: leftX + padding, baselineY: baseline)
                baseline += codeLineHeight
            }

            y += boxHeight + 18
            index += count
        }
    }

    func makeCodeLines(_ text: String, width: CGFloat) -> [CTLine] {
        let codeColor = CGColor(red: 0.12, green: 0.11, blue: 0.10, alpha: 1)
        let rawLines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var lines: [CTLine] = []

        for rawLine in rawLines {
            let content = rawLine.isEmpty ? " " : rawLine
            let attributed = NSAttributedString(string: content, attributes: [
                kCTFontAttributeName as NSAttributedString.Key: codeFont,
                kCTForegroundColorAttributeName as NSAttributedString.Key: codeColor
            ])
            let typesetter = CTTypesetterCreateWithAttributedString(attributed)
            var start = 0
            let length = attributed.length

            while start < max(length, 1) {
                let suggested = CTTypesetterSuggestLineBreak(typesetter, start, Double(width))
                let count = max(1, min(suggested, length - start))
                lines.append(CTTypesetterCreateLine(typesetter, CFRange(location: start, length: count)))
                start += count
            }
        }

        return lines
    }

    func loadImage(path: String) -> CGImage? {
        let url = resolveImageURL(path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    func resolveImageURL(_ path: String) -> URL {
        let cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanPath.hasPrefix("/") || cleanPath.hasPrefix("~") {
            return expandedFileURL(cleanPath)
        }
        if let url = URL(string: cleanPath), url.scheme != nil {
            return url
        }
        return inputDirectory.appendingPathComponent(cleanPath).standardizedFileURL
    }

    func makeInlineAttributed(_ text: String) -> NSMutableAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [
            kCTFontAttributeName as NSAttributedString.Key: bodyFont,
            kCTForegroundColorAttributeName as NSAttributedString.Key: blackColor
        ])

        let nsText = text as NSString
        let patterns = [
            #"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#,
            #"https?://[^\s]+"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
                for match in matches {
                    result.addAttribute(kCTForegroundColorAttributeName as NSAttributedString.Key, value: accentColor, range: match.range)
                }
            }
        }
        return result
    }
}

func printUsage(to stream: UnsafeMutablePointer<FILE>) {
    let executable = URL(fileURLWithPath: CommandLine.arguments[0]).lastPathComponent
    fputs("""
    \(appName) \(appVersion)

    Usage:
      \(executable) input.md [output.pdf]
      \(executable) input.md -o output.pdf

    Options:
      -o, --output <path>  Write PDF to this path
      -h, --help           Show this help
      --version            Show version

    Environment:
      KUMA_FONT_DIR         Register .otf, .ttf, and .ttc fonts from a local directory
      KUMA_BODY_FONT        Body font PostScript name. Default: \(defaultBodyFontName)
      KUMA_HEADING_FONT     Heading font PostScript name. Default: \(defaultHeadingFontName)
      KUMA_CODE_FONT        Code font PostScript name. Default: \(defaultCodeFontName)

    """, stream)
}

func usageError(_ message: String) -> Never {
    fputs("Error: \(message)\n\n", stderr)
    printUsage(to: stderr)
    exit(2)
}

func expandedFileURL(_ path: String) -> URL {
    URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
}

func parseArguments(_ rawArgs: [String]) -> (inputURL: URL, outputURL: URL) {
    var positionals: [String] = []
    var outputPath: String?
    var index = 0

    while index < rawArgs.count {
        let arg = rawArgs[index]

        switch arg {
        case "-h", "--help", "help":
            printUsage(to: stdout)
            exit(0)
        case "--version":
            print("\(appName) \(appVersion)")
            exit(0)
        case "-o", "--output":
            let valueIndex = index + 1
            guard valueIndex < rawArgs.count else {
                usageError("\(arg) needs a path")
            }
            outputPath = rawArgs[valueIndex]
            index += 2
            continue
        default:
            if arg.hasPrefix("-") {
                usageError("unknown option \(arg)")
            }
            positionals.append(arg)
        }

        index += 1
    }

    guard !positionals.isEmpty else {
        usageError("missing input Markdown file")
    }
    guard positionals.count <= 2 else {
        usageError("too many positional arguments")
    }
    if outputPath != nil && positionals.count == 2 {
        usageError("use either positional output.pdf or -o, not both")
    }

    let inputURL = expandedFileURL(positionals[0])
    let resolvedOutputPath = outputPath ?? positionals.dropFirst().first
    let outputURL = resolvedOutputPath.map(expandedFileURL)
        ?? inputURL.deletingPathExtension().appendingPathExtension("pdf")

    return (inputURL, outputURL)
}

func registerFonts(from directoryPath: String?) {
    guard let directoryPath, !directoryPath.isEmpty else { return }

    let directoryURL = expandedFileURL(directoryPath)
    guard let files = FileManager.default.enumerator(
        at: directoryURL,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        fputs("Warning: could not read KUMA_FONT_DIR at \(directoryURL.path)\n", stderr)
        return
    }

    let supportedExtensions = Set(["otf", "ttf", "ttc"])
    for case let fileURL as URL in files where supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
        let url = fileURL as CFURL
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url, .process, &error) {
            // Fonts may already be registered in this process.
            _ = error
        }
    }
}

func font(named name: String, size: CGFloat) -> CTFont {
    CTFontCreateWithName(name as CFString, size, nil)
}

func parseMarkdown(_ markdown: String) -> [Block] {
    var blocks: [Block] = []
    var paragraph: [String] = []
    var codeLanguage: String?
    var codeLines: [String] = []

    func flushParagraph() {
        if !paragraph.isEmpty {
            blocks.append(.paragraph(paragraph.joined(separator: " ")))
            paragraph.removeAll()
        }
    }

    for raw in markdown.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false) {
        let line = String(raw)
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if codeLanguage != nil {
            if trimmed.hasPrefix("```") {
                blocks.append(.code(language: codeLanguage, text: codeLines.joined(separator: "\n")))
                codeLanguage = nil
                codeLines.removeAll()
            } else {
                codeLines.append(line)
            }
            continue
        }

        if trimmed.isEmpty {
            flushParagraph()
            continue
        }

        if let match = trimmed.oneCapture(#"^```\s*([A-Za-z0-9_+.-]*)\s*$"#) {
            flushParagraph()
            codeLanguage = match.isEmpty ? nil : match
            if codeLanguage == nil {
                codeLanguage = ""
            }
            continue
        }

        if let match = trimmed.twoCaptures(#"^(#{1,6})\s+(.+)$"#) {
            flushParagraph()
            blocks.append(.heading(level: match.0.count, text: match.1))
            continue
        }

        if let match = trimmed.twoCaptures(#"^!\[([^\]]*)\]\(([^)]+)\)\s*$"#) {
            flushParagraph()
            blocks.append(.image(alt: match.0, path: match.1))
            continue
        }

        if let match = trimmed.oneCapture(#"^[-*]\s+(.+)$"#) {
            flushParagraph()
            blocks.append(.bullet(match))
            continue
        }

        paragraph.append(trimmed)
    }

    flushParagraph()
    if codeLanguage != nil {
        blocks.append(.code(language: codeLanguage, text: codeLines.joined(separator: "\n")))
    }
    return blocks
}

extension String {
    func oneCapture(_ pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = self as NSString
        guard let match = regex.firstMatch(in: self, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges >= 2 else { return nil }
        return ns.substring(with: match.range(at: 1))
    }

    func twoCaptures(_ pattern: String) -> (String, String)? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = self as NSString
        guard let match = regex.firstMatch(in: self, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges >= 3 else { return nil }
        return (ns.substring(with: match.range(at: 1)), ns.substring(with: match.range(at: 2)))
    }
}

let (inputURL, outputURL) = parseArguments(Array(CommandLine.arguments.dropFirst()))
let markdown = try String(contentsOf: inputURL, encoding: .utf8)
let blocks = parseMarkdown(markdown)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let environment = ProcessInfo.processInfo.environment
registerFonts(from: environment["KUMA_FONT_DIR"])

let bodyFont = font(named: environment["KUMA_BODY_FONT"] ?? defaultBodyFontName, size: 11)
let headingFont = font(named: environment["KUMA_HEADING_FONT"] ?? defaultHeadingFontName, size: 18)
let codeFont = font(named: environment["KUMA_CODE_FONT"] ?? defaultCodeFontName, size: 9.5)

guard let consumer = CGDataConsumer(url: outputURL as CFURL) else {
    fatalError("Could not create PDF output at \(outputURL.path)")
}

var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
    fatalError("Could not create PDF context")
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
    case .bullet(let text):
        renderer.drawBullet(text, previous: previous)
    case .image(let alt, let path):
        renderer.drawImage(alt: alt, path: path, previous: previous)
    case .code(let language, let text):
        renderer.drawCode(language: language, text: text, previous: previous)
    }
    previous = block
}
renderer.endPage()
context.closePDF()

print(outputURL.path)
