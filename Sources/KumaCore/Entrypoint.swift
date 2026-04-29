import Darwin
import Foundation

public func runKumaCLI() {
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
}
