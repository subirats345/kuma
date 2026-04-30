import Foundation

func parseInlineRuns(_ text: String, style: InlineStyle = InlineStyle()) -> [InlineRun] {
    var runs: [InlineRun] = []
    var literal = ""
    var index = text.startIndex

    func flushLiteral() {
        if !literal.isEmpty {
            runs.append(InlineRun(text: literal, style: style))
            literal.removeAll()
        }
    }

    func indexAfter(_ marker: String, from position: String.Index) -> String.Index {
        text.index(position, offsetBy: marker.count)
    }

    func closingRange(for marker: String, after position: String.Index) -> Range<String.Index>? {
        text.range(of: marker, range: position..<text.endIndex)
    }

    while index < text.endIndex {
        let next = text.index(after: index)

        if text[index] == "\\" {
            if next < text.endIndex {
                literal.append(text[next])
                index = text.index(after: next)
            } else {
                literal.append(text[index])
                index = next
            }
            continue
        }

        if text[index...].hasPrefix("`"), let close = closingRange(for: "`", after: next) {
            flushLiteral()
            var codeStyle = style
            codeStyle.code = true
            runs.append(InlineRun(text: String(text[next..<close.lowerBound]), style: codeStyle))
            index = close.upperBound
            continue
        }

        if text[index...].hasPrefix("["),
           let closeBracket = closingRange(for: "]", after: next),
           closeBracket.upperBound < text.endIndex,
           text[closeBracket.upperBound] == "(" {
            let destinationStart = text.index(after: closeBracket.upperBound)
            if let closeParen = closingRange(for: ")", after: destinationStart) {
                flushLiteral()
                var linkStyle = style
                linkStyle.link = true
                linkStyle.linkDestination = normalizedLinkDestination(String(text[destinationStart..<closeParen.lowerBound]))
                runs.append(contentsOf: parseInlineRuns(String(text[next..<closeBracket.lowerBound]), style: linkStyle))
                index = closeParen.upperBound
                continue
            }
        }

        if text[index...].hasPrefix("<"), let close = closingRange(for: ">", after: next) {
            let content = String(text[next..<close.lowerBound])
            if isAutolink(content) {
                flushLiteral()
                var linkStyle = style
                linkStyle.link = true
                linkStyle.linkDestination = normalizedLinkDestination(content)
                runs.append(InlineRun(text: content, style: linkStyle))
                index = close.upperBound
                continue
            }
        }

        if text[index...].hasPrefix("***") {
            let contentStart = indexAfter("***", from: index)
            if let close = closingRange(for: "***", after: contentStart) {
                flushLiteral()
                var emphasisStyle = style
                emphasisStyle.bold = true
                emphasisStyle.italic = true
                runs.append(contentsOf: parseInlineRuns(String(text[contentStart..<close.lowerBound]), style: emphasisStyle))
                index = close.upperBound
                continue
            }
        }

        if text[index...].hasPrefix("___") {
            let contentStart = indexAfter("___", from: index)
            if let close = closingRange(for: "___", after: contentStart) {
                flushLiteral()
                var emphasisStyle = style
                emphasisStyle.bold = true
                emphasisStyle.italic = true
                runs.append(contentsOf: parseInlineRuns(String(text[contentStart..<close.lowerBound]), style: emphasisStyle))
                index = close.upperBound
                continue
            }
        }

        if text[index...].hasPrefix("**") {
            let contentStart = indexAfter("**", from: index)
            if let close = closingRange(for: "**", after: contentStart) {
                flushLiteral()
                var boldStyle = style
                boldStyle.bold = true
                runs.append(contentsOf: parseInlineRuns(String(text[contentStart..<close.lowerBound]), style: boldStyle))
                index = close.upperBound
                continue
            }
        }

        if text[index...].hasPrefix("__") {
            let contentStart = indexAfter("__", from: index)
            if let close = closingRange(for: "__", after: contentStart) {
                flushLiteral()
                var boldStyle = style
                boldStyle.bold = true
                runs.append(contentsOf: parseInlineRuns(String(text[contentStart..<close.lowerBound]), style: boldStyle))
                index = close.upperBound
                continue
            }
        }

        if text[index...].hasPrefix("~~") {
            let contentStart = indexAfter("~~", from: index)
            if let close = closingRange(for: "~~", after: contentStart) {
                flushLiteral()
                var strikeStyle = style
                strikeStyle.strikethrough = true
                runs.append(contentsOf: parseInlineRuns(String(text[contentStart..<close.lowerBound]), style: strikeStyle))
                index = close.upperBound
                continue
            }
        }

        if text[index] == "*" {
            if let close = closingRange(for: "*", after: next), close.lowerBound > next {
                flushLiteral()
                var italicStyle = style
                italicStyle.italic = true
                runs.append(contentsOf: parseInlineRuns(String(text[next..<close.lowerBound]), style: italicStyle))
                index = close.upperBound
                continue
            }
        }

        if text[index] == "_" {
            if let close = closingRange(for: "_", after: next), close.lowerBound > next {
                flushLiteral()
                var italicStyle = style
                italicStyle.italic = true
                runs.append(contentsOf: parseInlineRuns(String(text[next..<close.lowerBound]), style: italicStyle))
                index = close.upperBound
                continue
            }
        }

        literal.append(text[index])
        index = next
    }

    flushLiteral()
    return runs
}

func isAutolink(_ text: String) -> Bool {
    text.range(of: #"^(https?://[^\s]+|[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,})$"#, options: [.regularExpression, .caseInsensitive]) != nil
}

func normalizedLinkDestination(_ destination: String) -> String {
    let trimmed = destination.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.range(of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#, options: [.regularExpression, .caseInsensitive]) != nil {
        return "mailto:\(trimmed)"
    }
    return trimmed
}
