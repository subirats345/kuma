import Foundation

func parseMarkdown(_ markdown: String) -> [Block] {
    var blocks: [Block] = []
    var paragraph: [String] = []
    var codeLanguage: String?
    var codeFence: String?
    var codeLines: [String] = []
    let lines = markdown
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map(String.init)
    var index = 0

    func flushParagraph() {
        if !paragraph.isEmpty {
            blocks.append(.paragraph(joinParagraph(paragraph)))
            paragraph.removeAll()
        }
    }

    if lines.first?.trimmingCharacters(in: .whitespaces) == "---" {
        var frontmatterEnd: Int?
        var cursor = 1
        while cursor < lines.count {
            if lines[cursor].trimmingCharacters(in: .whitespaces) == "---" {
                frontmatterEnd = cursor
                break
            }
            cursor += 1
        }
        if let frontmatterEnd {
            index = frontmatterEnd + 1
        }
    }

    while index < lines.count {
        let line = lines[index]
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if codeLanguage != nil {
            if let fence = codeFence, trimmed.hasPrefix(fence) {
                blocks.append(.code(language: codeLanguage, text: codeLines.joined(separator: "\n")))
                codeLanguage = nil
                codeFence = nil
                codeLines.removeAll()
            } else {
                codeLines.append(line)
            }
            index += 1
            continue
        }

        if trimmed.isEmpty {
            flushParagraph()
            index += 1
            continue
        }

        if let match = trimmed.twoCaptures(#"^(```+|~~~+)\s*([A-Za-z0-9_+.-]*)\s*$"#) {
            flushParagraph()
            codeFence = match.0
            codeLanguage = match.1
            index += 1
            continue
        }

        if let quote = blockquoteContent(line) {
            flushParagraph()
            var quoteLines: [String] = []
            while index < lines.count, let content = blockquoteContent(lines[index]) {
                quoteLines.append(content)
                index += 1
            }
            blocks.append(.blockquote(joinParagraph(quoteLines.isEmpty ? [quote] : quoteLines)))
            continue
        }

        if let table = parseTable(lines: lines, startingAt: index) {
            flushParagraph()
            blocks.append(.table(table.block))
            index = table.nextIndex
            continue
        }

        if isHorizontalRule(trimmed) {
            flushParagraph()
            blocks.append(.horizontalRule)
            index += 1
            continue
        }

        if let match = trimmed.twoCaptures(#"^(#{1,6})\s+(.+)$"#) {
            flushParagraph()
            blocks.append(.heading(level: match.0.count, text: match.1))
            index += 1
            continue
        }

        if let match = trimmed.twoCaptures(#"^!\[([^\]]*)\]\(([^)]+)\)\s*$"#) {
            flushParagraph()
            blocks.append(.image(alt: match.0, path: match.1))
            index += 1
            continue
        }

        if let listItem = parseListItem(line) {
            flushParagraph()
            blocks.append(.listItem(marker: listItem.marker, level: listItem.level, text: listItem.text))
            index += 1
            continue
        }

        paragraph.append(normalizedParagraphLine(line))
        index += 1
    }

    flushParagraph()
    if codeLanguage != nil {
        blocks.append(.code(language: codeLanguage, text: codeLines.joined(separator: "\n")))
    }
    return blocks
}

func normalizedParagraphLine(_ line: String) -> String {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    if line.hasSuffix("  ") {
        return trimmed + "\n"
    }
    if trimmed.hasSuffix("\\") {
        return String(trimmed.dropLast()) + "\n"
    }
    return trimmed
}

func joinParagraph(_ lines: [String]) -> String {
    var result = ""
    for line in lines {
        if result.isEmpty {
            result = line
        } else if result.hasSuffix("\n") {
            result += line
        } else if line == "\n" {
            result += "\n"
        } else {
            result += " " + line
        }
    }
    return result
}

func blockquoteContent(_ line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix(">") else { return nil }
    var content = String(trimmed.dropFirst())
    if content.hasPrefix(" ") {
        content.removeFirst()
    }
    return normalizedParagraphLine(content)
}

func isHorizontalRule(_ trimmed: String) -> Bool {
    let compact = trimmed.replacingOccurrences(of: " ", with: "")
    guard compact.count >= 3, let first = compact.first, ["-", "*", "_"].contains(first) else {
        return false
    }
    return compact.allSatisfy { $0 == first }
}

func parseListItem(_ line: String) -> (marker: ListMarker, level: Int, text: String)? {
    let indent = leadingIndentWidth(line)
    let level = min(5, indent / 2)
    let trimmed = line.trimmingCharacters(in: .whitespaces)

    if let match = trimmed.twoCaptures(#"^[-*+]\s+\[([ xX])\]\s+(.+)$"#) {
        return (.task(match.0.lowercased() == "x"), level, match.1)
    }

    if let match = trimmed.twoCaptures(#"^(\d+)[.)]\s+(.+)$"#), let number = Int(match.0) {
        return (.ordered(number), level, match.1)
    }

    if let match = trimmed.oneCapture(#"^[-*+]\s+(.+)$"#) {
        return (.unordered, level, match)
    }

    return nil
}

func leadingIndentWidth(_ line: String) -> Int {
    var width = 0
    for char in line {
        if char == " " {
            width += 1
        } else if char == "\t" {
            width += 4
        } else {
            break
        }
    }
    return width
}

func parseTable(lines: [String], startingAt index: Int) -> (block: TableBlock, nextIndex: Int)? {
    guard index + 1 < lines.count else { return nil }
    let headerLine = lines[index].trimmingCharacters(in: .whitespaces)
    let separatorLine = lines[index + 1].trimmingCharacters(in: .whitespaces)
    guard headerLine.contains("|"), isTableSeparator(separatorLine) else { return nil }

    let headers = parseTableRow(headerLine)
    guard !headers.isEmpty else { return nil }

    var rows: [[String]] = []
    var nextIndex = index + 2
    while nextIndex < lines.count {
        let line = lines[nextIndex].trimmingCharacters(in: .whitespaces)
        if line.isEmpty || !line.contains("|") {
            break
        }
        rows.append(parseTableRow(line))
        nextIndex += 1
    }

    return (TableBlock(headers: headers, rows: rows), nextIndex)
}

func parseTableRow(_ line: String) -> [String] {
    var value = line.trimmingCharacters(in: .whitespaces)
    if value.hasPrefix("|") {
        value.removeFirst()
    }
    if value.hasSuffix("|") {
        value.removeLast()
    }
    return value.split(separator: "|", omittingEmptySubsequences: false)
        .map { String($0).trimmingCharacters(in: .whitespaces) }
}

func isTableSeparator(_ line: String) -> Bool {
    guard line.contains("-") else { return false }
    let cells = parseTableRow(line)
    guard !cells.isEmpty else { return false }
    return cells.allSatisfy { cell in
        cell.range(of: #"^:?-{3,}:?$"#, options: .regularExpression) != nil
    }
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
