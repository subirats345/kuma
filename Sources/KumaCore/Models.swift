import Foundation

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

enum ListMarker: Equatable {
    case unordered
    case ordered(Int)
    case task(Bool)
}

struct TableBlock: Equatable {
    let headers: [String]
    let rows: [[String]]
}

struct InlineStyle: Equatable {
    var bold = false
    var italic = false
    var code = false
    var link = false
    var strikethrough = false
}

struct InlineRun: Equatable {
    let text: String
    let style: InlineStyle
}

enum Block: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case listItem(marker: ListMarker, level: Int, text: String)
    case image(alt: String, path: String)
    case code(language: String?, text: String)
    case blockquote(String)
    case horizontalRule
    case table(TableBlock)

    var isHeading: Bool {
        if case .heading = self {
            return true
        }
        return false
    }

    var isListItem: Bool {
        if case .listItem = self {
            return true
        }
        return false
    }
}
