import Darwin
import Foundation
import CoreText

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

Write **plain Markdown** and render it into a quiet native PDF.

## Notes

- Keep sections short.
- Use simple headings and `inline code`.
- Add links such as https://github.com/subirats345/kuma.
- Add emails such as hello@example.com.
- Track tasks with `- [ ]` and `- [x]`.

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
