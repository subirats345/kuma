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
let captionColor = CGColor(gray: 0.35, alpha: 1)
let codeTextColor = CGColor(red: 0.12, green: 0.11, blue: 0.10, alpha: 1)
let codeBackgroundColor = CGColor(red: 0.965, green: 0.955, blue: 0.935, alpha: 1)
let codeBorderColor = CGColor(red: 0.88, green: 0.86, blue: 0.82, alpha: 1)
let appName = "Kuma"
let appVersion = "0.6.0"
let defaultBodyFontName = "AvenirNext-Regular"
let defaultHeadingFontName = "AvenirNext-DemiBold"
let defaultCodeFontName = "Menlo-Regular"

struct RenderOptions {
    let inputURL: URL
    let outputURL: URL
    let openAfterRender: Bool
}

enum Command {
    case render(RenderOptions)
    case watch(RenderOptions)
    case initialize(URL)
    case interactive
}

enum KumaError: Error, CustomStringConvertible {
    case inputNotFound(URL)
    case inputIsDirectory(URL)
    case inputNotReadable(URL)
    case outputIsDirectory(URL)
    case cannotReadInput(URL, Error)
    case cannotCreateOutputDirectory(URL, Error)
    case cannotCreatePDF(URL)
    case cannotCreatePDFContext
    case cannotOpen(URL, Int32)
    case initFileExists(URL)
    case cannotWriteInitFile(URL, Error)
    case interactiveCancelled

    var description: String {
        switch self {
        case .inputNotFound(let url):
            return "input file not found: \(url.path)"
        case .inputIsDirectory(let url):
            return "input path is a directory, not a Markdown file: \(url.path)"
        case .inputNotReadable(let url):
            return "input file is not readable: \(url.path)"
        case .outputIsDirectory(let url):
            return "output path is a directory: \(url.path)"
        case .cannotReadInput(let url, let error):
            return "could not read \(url.path): \(error.localizedDescription)"
        case .cannotCreateOutputDirectory(let url, let error):
            return "could not create output directory \(url.path): \(error.localizedDescription)"
        case .cannotCreatePDF(let url):
            return "could not create PDF output at \(url.path)"
        case .cannotCreatePDFContext:
            return "could not create PDF drawing context"
        case .cannotOpen(let url, let status):
            return "could not open \(url.path) with macOS open (exit \(status))"
        case .initFileExists(let url):
            return "refusing to overwrite existing file: \(url.path)"
        case .cannotWriteInitFile(let url, let error):
            return "could not write \(url.path): \(error.localizedDescription)"
        case .interactiveCancelled:
            return "interactive session cancelled"
        }
    }
}

struct FileSignature: Equatable {
    let modificationDate: Date?
    let size: Int?
}

enum Block {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullet(String)
    case image(alt: String, path: String)
    case code(language: String?, text: String)

    var isHeading: Bool {
        if case .heading = self {
            return true
        }
        return false
    }
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
                y += 24
            } else if level == 3 {
                if case .heading(2, _) = previous {
                    y += 5
                } else {
                    y += 18
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
            nextGap = 34
        case 2:
            size = 18
            nextGap = 27
        default:
            size = 14
            nextGap = 19
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
        if let previous, !previous.isHeading {
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
                kCTForegroundColorAttributeName as NSAttributedString.Key: captionColor
            ])
            drawWrapped(caption, x: leftX, width: bodyWidth, lineHeight: 14)
            y += 8
        }
    }

    mutating func drawCode(language: String?, text: String, previous: Block?) {
        if let previous, !previous.isHeading {
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

            fillRect(x: leftX, topY: y, width: codeWidth, height: boxHeight, color: codeBackgroundColor)
            strokeRect(x: leftX, topY: y, width: codeWidth, height: boxHeight, color: codeBorderColor, lineWidth: 0.8)

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
        let rawLines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var lines: [CTLine] = []

        for rawLine in rawLines {
            let content = rawLine.isEmpty ? " " : rawLine
            let attributed = NSAttributedString(string: content, attributes: [
                kCTFontAttributeName as NSAttributedString.Key: codeFont,
                kCTForegroundColorAttributeName as NSAttributedString.Key: codeTextColor
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
      \(executable)
      \(executable) interactive
      \(executable) input.md [output.pdf]
      \(executable) input.md -o output.pdf
      \(executable) input.md --open
      \(executable) watch input.md [output.pdf]
      \(executable) init [path.md]

    Options:
      -o, --output <path>  Write PDF to this path
      --open              Open the PDF after rendering
      -h, --help           Show this help
      --version            Show version

    Commands:
      interactive          Pick input, output, open, and watch with prompts
      watch                Re-render when the input Markdown changes
      init                 Create a small starter Markdown file

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

func parseArguments(_ rawArgs: [String]) -> Command {
    guard let first = rawArgs.first else {
        return .interactive
    }

    switch first {
    case "-h", "--help", "help":
        printUsage(to: stdout)
        exit(0)
    case "--version":
        print("\(appName) \(appVersion)")
        exit(0)
    case "interactive":
        return .interactive
    case "watch":
        return .watch(parseRenderArguments(Array(rawArgs.dropFirst())))
    case "init":
        return .initialize(parseInitArguments(Array(rawArgs.dropFirst())))
    default:
        return .render(parseRenderArguments(rawArgs))
    }
}

func parseInitArguments(_ rawArgs: [String]) -> URL {
    var positionals: [String] = []

    for arg in rawArgs {
        switch arg {
        case "-h", "--help":
            printUsage(to: stdout)
            exit(0)
        default:
            if arg.hasPrefix("-") {
                usageError("unknown option \(arg)")
            }
            positionals.append(arg)
        }
    }

    guard positionals.count <= 1 else {
        usageError("init accepts at most one output path")
    }

    return expandedFileURL(positionals.first ?? "kuma-example.md")
}

func parseRenderArguments(_ rawArgs: [String]) -> RenderOptions {
    var positionals: [String] = []
    var outputPath: String?
    var openAfterRender = false
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
        case "--open":
            openAfterRender = true
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

    return RenderOptions(inputURL: inputURL, outputURL: outputURL, openAfterRender: openAfterRender)
}

func font(named name: String, size: CGFloat) -> CTFont {
    CTFontCreateWithName(name as CFString, size, nil)
}

func fileExists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path)
}

func isDirectory(_ url: URL) -> Bool {
    var isDirectory = ObjCBool(false)
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
        return false
    }
    return isDirectory.boolValue
}

func validateRenderPaths(inputURL: URL, outputURL: URL) throws {
    guard fileExists(inputURL) else {
        throw KumaError.inputNotFound(inputURL)
    }
    if isDirectory(inputURL) {
        throw KumaError.inputIsDirectory(inputURL)
    }
    guard FileManager.default.isReadableFile(atPath: inputURL.path) else {
        throw KumaError.inputNotReadable(inputURL)
    }
    if isDirectory(outputURL) {
        throw KumaError.outputIsDirectory(outputURL)
    }
}

func openURL(_ url: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = [url.path]
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus != 0 {
        throw KumaError.cannotOpen(url, process.terminationStatus)
    }
}

@discardableResult
func render(_ options: RenderOptions) throws -> URL {
    try renderMarkdownPDF(inputURL: options.inputURL, outputURL: options.outputURL)
    if options.openAfterRender {
        try openURL(options.outputURL)
    }
    return options.outputURL
}

func fileSignature(_ url: URL) -> FileSignature? {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
        return nil
    }
    return FileSignature(
        modificationDate: attributes[.modificationDate] as? Date,
        size: attributes[.size] as? Int
    )
}

func timestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter.string(from: Date())
}

func watch(_ options: RenderOptions) -> Never {
    print("Watching \(options.inputURL.path)")
    print("Writing \(options.outputURL.path)")
    print("Press Ctrl-C to stop.")
    fflush(stdout)

    var lastSignature: FileSignature?

    while true {
        guard let signature = fileSignature(options.inputURL) else {
            fputs("[\(timestamp())] Error: input file not found: \(options.inputURL.path)\n", stderr)
            fflush(stderr)
            Thread.sleep(forTimeInterval: 1)
            continue
        }

        if signature != lastSignature {
            do {
                try render(options)
                print("[\(timestamp())] Rendered \(options.outputURL.path)")
                fflush(stdout)
                lastSignature = signature
            } catch {
                fputs("[\(timestamp())] Error: \(describe(error))\n", stderr)
                fflush(stderr)
            }
        }

        Thread.sleep(forTimeInterval: 1)
    }
}

let starterMarkdown = """
# Kuma Example

Write plain Markdown and render it into a quiet native PDF.

## Notes

- Keep sections short.
- Use simple headings.
- Add links such as https://github.com/subirats345/kuma.
- Add emails such as hello@example.com.

## Code

```swift
let input = "note.md"
let output = "note.pdf"
print("Rendering \\(input) into \\(output)")
```

## Finish

Run `kuma kuma-example.md` to create the PDF.
"""

func initializeMarkdown(at url: URL) throws {
    if fileExists(url) {
        throw KumaError.initFileExists(url)
    }

    let directoryURL = url.deletingLastPathComponent()
    do {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try starterMarkdown.write(to: url, atomically: true, encoding: .utf8)
    } catch {
        throw KumaError.cannotWriteInitFile(url, error)
    }

    print(url.path)
}

func currentDirectoryURL() -> URL {
    URL(fileURLWithPath: FileManager.default.currentDirectoryPath).standardizedFileURL
}

func markdownFiles(in directoryURL: URL) -> [URL] {
    guard let files = try? FileManager.default.contentsOfDirectory(
        at: directoryURL,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    return files
        .filter { ["md", "markdown"].contains($0.pathExtension.lowercased()) }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
}

func prompt(_ message: String) throws -> String {
    print(message, terminator: "")
    fflush(stdout)
    guard let line = readLine() else {
        throw KumaError.interactiveCancelled
    }
    return line.trimmingCharacters(in: .whitespacesAndNewlines)
}

func promptYesNo(_ message: String, defaultValue: Bool) throws -> Bool {
    let suffix = defaultValue ? " [Y/n]: " : " [y/N]: "
    while true {
        let answer = try prompt(message + suffix).lowercased()
        if answer.isEmpty {
            return defaultValue
        }
        if ["y", "yes"].contains(answer) {
            return true
        }
        if ["n", "no"].contains(answer) {
            return false
        }
        print("Please answer yes or no.")
    }
}

func promptInputURL() throws -> URL {
    let files = markdownFiles(in: currentDirectoryURL())

    if !files.isEmpty {
        print("Markdown files:")
        for (index, fileURL) in files.enumerated() {
            print("  \(index + 1). \(fileURL.lastPathComponent)")
        }
        print("")
    }

    while true {
        let answer = try prompt("Markdown file or number: ")
        if answer.isEmpty {
            if files.count == 1 {
                return files[0]
            }
            print("Please enter a Markdown path or choose a number.")
            continue
        }

        if let selection = Int(answer), selection >= 1, selection <= files.count {
            return files[selection - 1]
        }

        return expandedFileURL(answer)
    }
}

func promptOutputURL(for inputURL: URL) throws -> URL {
    let defaultURL = inputURL.deletingPathExtension().appendingPathExtension("pdf")
    let answer = try prompt("Output PDF [\(defaultURL.path)]: ")
    if answer.isEmpty {
        return defaultURL
    }
    return expandedFileURL(answer)
}

func interactiveCommand() throws -> Command {
    print("\(appName) \(appVersion)")
    print("Interactive PDF render")
    print("")

    let inputURL = try promptInputURL()
    let outputURL = try promptOutputURL(for: inputURL)
    let openAfterRender = try promptYesNo("Open after render?", defaultValue: true)
    let useWatch = try promptYesNo("Watch for changes?", defaultValue: false)
    let options = RenderOptions(inputURL: inputURL, outputURL: outputURL, openAfterRender: openAfterRender)

    print("")
    if useWatch {
        return .watch(options)
    }
    return .render(options)
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
}

func describe(_ error: Error) -> String {
    if let error = error as? KumaError {
        return error.description
    }
    return error.localizedDescription
}

do {
    let command = parseArguments(Array(CommandLine.arguments.dropFirst()))
    let resolvedCommand: Command
    switch command {
    case .interactive:
        resolvedCommand = try interactiveCommand()
    default:
        resolvedCommand = command
    }

    switch resolvedCommand {
    case .render(let options):
        let outputURL = try render(options)
        print(outputURL.path)
    case .watch(let options):
        watch(options)
    case .initialize(let url):
        try initializeMarkdown(at: url)
    case .interactive:
        throw KumaError.interactiveCancelled
    }
} catch {
    fputs("Error: \(describe(error))\n", stderr)
    exit(1)
}
