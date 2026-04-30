import CoreFoundation
import CoreGraphics
import CoreText
import Foundation
import ImageIO

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
        drawStrikethroughs(line, x: x, baselineY: baselineY)
        drawLinkAnnotations(line, x: x, baselineY: baselineY)
    }

    func drawStrikethroughs(_ line: CTLine, x: CGFloat, baselineY: CGFloat) {
        let runs = CTLineGetGlyphRuns(line) as NSArray
        let baseline = pageHeight - baselineY

        context.saveGState()
        context.setLineWidth(0.55)

        for case let run as CTRun in runs {
            let attributes = CTRunGetAttributes(run) as NSDictionary
            guard attributes[kumaStrikethroughAttribute] != nil else {
                continue
            }

            let range = CTRunGetStringRange(run)
            let runX = x + CTLineGetOffsetForStringIndex(line, range.location, nil)
            let width = CGFloat(CTRunGetTypographicBounds(run, CFRange(location: 0, length: 0), nil, nil, nil))
            let colorValue = attributes[kCTForegroundColorAttributeName as NSAttributedString.Key]
            let fontValue = attributes[kCTFontAttributeName as NSAttributedString.Key]
            let color = colorValue == nil ? blackColor : colorValue as! CGColor
            let font = fontValue == nil ? bodyFont : fontValue as! CTFont
            let strikeY = baseline + (CTFontGetXHeight(font) * 0.45)

            context.setStrokeColor(color)
            context.move(to: CGPoint(x: runX, y: strikeY))
            context.addLine(to: CGPoint(x: runX + width, y: strikeY))
            context.strokePath()
        }

        context.restoreGState()
    }

    func drawLinkAnnotations(_ line: CTLine, x: CGFloat, baselineY: CGFloat) {
        let runs = CTLineGetGlyphRuns(line) as NSArray
        let baseline = pageHeight - baselineY

        for case let run as CTRun in runs {
            let attributes = CTRunGetAttributes(run) as NSDictionary
            guard let destination = attributes[kumaLinkAttribute] as? String,
                  let url = URL(string: destination) else {
                continue
            }

            let range = CTRunGetStringRange(run)
            let runX = x + CTLineGetOffsetForStringIndex(line, range.location, nil)
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            let width = CGFloat(CTRunGetTypographicBounds(run, CFRange(location: 0, length: 0), &ascent, &descent, nil))
            guard width > 0 else { continue }

            let rect = CGRect(
                x: runX,
                y: baseline - descent - 1,
                width: width,
                height: ascent + descent + 2
            )
            context.setURL(url as CFURL, for: rect)
        }
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
                if char == 32 || char == 9 {
                    start += 1
                } else {
                    break
                }
            }
            if start >= length { break }

            if string.character(at: start) == 10 {
                y += lineHeight
                start += 1
                continue
            }

            if y > maxBaselineY {
                newPage()
            }

            var count = CTTypesetterSuggestLineBreak(typesetter, start, Double(width))
            var consumesNewline = false
            let remainingRange = NSRange(location: start, length: length - start)
            let newlineRange = string.range(of: "\n", options: [], range: remainingRange)
            if newlineRange.location != NSNotFound && newlineRange.location < start + count {
                count = newlineRange.location - start
                consumesNewline = true
            }

            if count > 0 {
                let line = CTTypesetterCreateLine(typesetter, CFRange(location: start, length: count))
                drawLine(line, x: x, baselineY: y)
            }
            y += lineHeight
            start += count
            if consumesNewline {
                start += 1
            }
        }
    }

    func wrappedLineRanges(_ attributed: NSAttributedString, width: CGFloat) -> [CFRange] {
        let typesetter = CTTypesetterCreateWithAttributedString(attributed)
        let string = attributed.string as NSString
        var ranges: [CFRange] = []
        var start = 0
        let length = attributed.length

        while start < length {
            while start < length {
                let char = string.character(at: start)
                if char == 32 || char == 9 {
                    start += 1
                } else {
                    break
                }
            }
            if start >= length { break }

            if string.character(at: start) == 10 {
                ranges.append(CFRange(location: start, length: 0))
                start += 1
                continue
            }

            var count = CTTypesetterSuggestLineBreak(typesetter, start, Double(width))
            var consumesNewline = false
            let remainingRange = NSRange(location: start, length: length - start)
            let newlineRange = string.range(of: "\n", options: [], range: remainingRange)
            if newlineRange.location != NSNotFound && newlineRange.location < start + count {
                count = newlineRange.location - start
                consumesNewline = true
            }

            ranges.append(CFRange(location: start, length: count))
            start += count
            if consumesNewline {
                start += 1
            }
        }

        return ranges.isEmpty ? [CFRange(location: 0, length: 0)] : ranges
    }

    func measuredLineCount(_ attributed: NSAttributedString, width: CGFloat) -> Int {
        wrappedLineRanges(attributed, width: width).count
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

    mutating func drawListItem(marker: ListMarker, level: Int, text: String, previous: Block?) {
        if case .paragraph = previous {
            y += 20
        } else if let previous, !previous.isListItem && !previous.isHeading {
            y += 8
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
                drawListMarker(marker, level: level, baselineY: y)
                firstLine = false
            }

            let textX = listTextX(level: level)
            let width = listWidth(level: level)
            let count = CTTypesetterSuggestLineBreak(typesetter, start, Double(width))
            let line = CTTypesetterCreateLine(typesetter, CFRange(location: start, length: count))
            drawLine(line, x: textX, baselineY: y)
            y += bodyLineHeight
            start += count
        }
    }

    func listTextX(level: Int) -> CGFloat {
        bulletTextX + (CGFloat(max(0, level)) * 18)
    }

    func listMarkerX(level: Int) -> CGFloat {
        bulletDotX + (CGFloat(max(0, level)) * 18)
    }

    func listWidth(level: Int) -> CGFloat {
        max(120, bodyWidth - (listTextX(level: level) - leftX))
    }

    func drawListMarker(_ marker: ListMarker, level: Int, baselineY: CGFloat) {
        switch marker {
        case .unordered:
            drawBulletDot(level: level, baselineY: baselineY)
        case .ordered(let number):
            drawOrderedMarker(number: number, level: level, baselineY: baselineY)
        case .task(let checked):
            drawTaskMarker(checked: checked, level: level, baselineY: baselineY)
        }
    }

    func drawBulletDot(level: Int, baselineY: CGFloat) {
        context.saveGState()
        context.setFillColor(accentColor)
        let radius: CGFloat = 2.45
        let centerY = baselineY - (CTFontGetCapHeight(bodyFont) / 2)
        let center = CGPoint(x: listMarkerX(level: level), y: pageHeight - centerY)
        context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.restoreGState()
    }

    func drawOrderedMarker(number: Int, level: Int, baselineY: CGFloat) {
        let markerFont = CTFontCreateCopyWithAttributes(bodyFont, 9.5, nil, nil)
        let attributed = NSAttributedString(string: "\(number).", attributes: [
            kCTFontAttributeName as NSAttributedString.Key: markerFont,
            kCTForegroundColorAttributeName as NSAttributedString.Key: accentColor
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        let markerWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        drawLine(line, x: listTextX(level: level) - markerWidth - 8, baselineY: baselineY)
    }

    func drawTaskMarker(checked: Bool, level: Int, baselineY: CGFloat) {
        let size: CGFloat = 7
        let centerY = baselineY - (CTFontGetCapHeight(bodyFont) / 2)
        let rect = CGRect(
            x: listTextX(level: level) - 18,
            y: pageHeight - centerY - (size / 2),
            width: size,
            height: size
        )

        context.saveGState()
        context.setStrokeColor(accentColor)
        context.setLineWidth(0.9)
        context.stroke(rect)
        if checked {
            context.setStrokeColor(accentColor)
            context.setLineWidth(1.1)
            context.move(to: CGPoint(x: rect.minX + 1.4, y: rect.midY))
            context.addLine(to: CGPoint(x: rect.minX + 3, y: rect.minY + 1.6))
            context.addLine(to: CGPoint(x: rect.maxX - 1, y: rect.maxY - 1.4))
            context.strokePath()
        }
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

    mutating func drawBlockquote(_ text: String, previous: Block?) {
        if let previous, !previous.isHeading {
            y += 13
        }

        let attr = makeInlineAttributed(text, baseColor: captionColor)
        let quoteX = leftX + 15
        let quoteWidth = bodyWidth - 18
        let lineCount = measuredLineCount(attr, width: quoteWidth)
        let quoteHeight = CGFloat(lineCount) * bodyLineHeight + 4

        if y + quoteHeight > maxBaselineY {
            newPage()
        }

        context.saveGState()
        context.setStrokeColor(accentColor)
        context.setLineWidth(1.4)
        let lineX = leftX + 3
        let topY = y - 4
        context.move(to: CGPoint(x: lineX, y: pageHeight - topY))
        context.addLine(to: CGPoint(x: lineX, y: pageHeight - (topY + quoteHeight)))
        context.strokePath()
        context.restoreGState()

        drawWrapped(attr, x: quoteX, width: quoteWidth, lineHeight: bodyLineHeight)
        y += 8
    }

    mutating func drawHorizontalRule(previous: Block?) {
        if let previous, !previous.isHeading {
            y += 12
        }
        if y > maxBaselineY - 24 {
            newPage()
        }

        context.saveGState()
        context.setStrokeColor(tableLineColor)
        context.setLineWidth(0.8)
        context.move(to: CGPoint(x: leftX, y: pageHeight - y))
        context.addLine(to: CGPoint(x: leftX + bodyWidth, y: pageHeight - y))
        context.strokePath()
        context.restoreGState()

        y += 24
    }

    mutating func drawTable(_ table: TableBlock, previous: Block?) {
        if let previous, !previous.isHeading {
            y += 15
        }

        let rows = [table.headers] + table.rows
        let columnCount = max(1, rows.map(\.count).max() ?? 1)
        let columnWidth = bodyWidth / CGFloat(columnCount)
        let padding: CGFloat = 5
        let tableLineHeight: CGFloat = 13
        let headerFont = CTFontCreateCopyWithAttributes(headingFont, 9.5, nil, nil)

        for (rowIndex, row) in rows.enumerated() {
            var cellRanges: [[CFRange]] = []
            var cellAttributed: [NSAttributedString] = []
            var maxLines = 1

            for column in 0..<columnCount {
                let value = column < row.count ? row[column] : ""
                let attr = rowIndex == 0
                    ? makeInlineAttributed(value, baseFont: headerFont)
                    : makeInlineAttributed(value)
                let ranges = wrappedLineRanges(attr, width: columnWidth - (padding * 2))
                maxLines = max(maxLines, ranges.count)
                cellAttributed.append(attr)
                cellRanges.append(ranges)
            }

            let rowHeight = max(CGFloat(maxLines) * tableLineHeight + (padding * 2), rowIndex == 0 ? 24 : 22)
            if y + rowHeight > maxBaselineY {
                newPage()
            }

            if rowIndex == 0 {
                fillRect(x: leftX, topY: y, width: bodyWidth, height: rowHeight, color: tableHeaderColor)
            }

            context.saveGState()
            context.setStrokeColor(tableLineColor)
            context.setLineWidth(0.55)
            let top = pageHeight - y
            let bottom = pageHeight - (y + rowHeight)
            context.move(to: CGPoint(x: leftX, y: top))
            context.addLine(to: CGPoint(x: leftX + bodyWidth, y: top))
            context.move(to: CGPoint(x: leftX, y: bottom))
            context.addLine(to: CGPoint(x: leftX + bodyWidth, y: bottom))
            for column in 0...columnCount {
                let x = leftX + (CGFloat(column) * columnWidth)
                context.move(to: CGPoint(x: x, y: top))
                context.addLine(to: CGPoint(x: x, y: bottom))
            }
            context.strokePath()
            context.restoreGState()

            for column in 0..<columnCount {
                let attr = cellAttributed[column]
                let ranges = cellRanges[column]
                var baseline = y + padding + 10
                let x = leftX + (CGFloat(column) * columnWidth) + padding
                for range in ranges where range.length > 0 {
                    let line = CTLineCreateWithAttributedString(attr.attributedSubstring(from: NSRange(location: range.location, length: range.length)))
                    drawLine(line, x: x, baselineY: baseline)
                    baseline += tableLineHeight
                }
            }

            y += rowHeight
        }

        y += 16
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

    func makeInlineAttributed(_ text: String, baseColor: CGColor = blackColor, baseFont: CTFont? = nil) -> NSMutableAttributedString {
        let selectedBaseFont = baseFont ?? bodyFont
        let result = NSMutableAttributedString()
        for run in parseInlineRuns(text) {
            result.append(NSAttributedString(string: run.text, attributes: inlineAttributes(for: run.style, baseColor: baseColor, baseFont: selectedBaseFont)))
        }

        let nsText = result.string as NSString
        let patterns = [
            #"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#,
            #"https?://[^\s]+"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: result.string, range: NSRange(location: 0, length: nsText.length))
                for match in matches {
                    let linkRange = trimmedLinkRange(match.range, in: nsText)
                    guard linkRange.length > 0 else { continue }
                    result.addAttribute(kCTForegroundColorAttributeName as NSAttributedString.Key, value: accentColor, range: linkRange)
                    let destination = nsText.substring(with: linkRange)
                    result.addAttribute(kumaLinkAttribute, value: normalizedLinkDestination(destination), range: linkRange)
                }
            }
        }
        return result
    }

    func trimmedLinkRange(_ range: NSRange, in text: NSString) -> NSRange {
        var length = range.length
        let trailingPunctuation = CharacterSet(charactersIn: ".,;:!?)")
        while length > 0 {
            let character = text.substring(with: NSRange(location: range.location + length - 1, length: 1))
            if character.rangeOfCharacter(from: trailingPunctuation) == nil {
                break
            }
            length -= 1
        }
        return NSRange(location: range.location, length: length)
    }

    func inlineAttributes(for style: InlineStyle, baseColor: CGColor, baseFont: CTFont) -> [NSAttributedString.Key: Any] {
        let size = CTFontGetSize(baseFont)
        let selectedFont: CTFont
        if style.code {
            selectedFont = CTFontCreateCopyWithAttributes(codeFont, size - 0.5, nil, nil)
        } else if style.bold && style.italic {
            selectedFont = font(named: "AvenirNext-DemiBoldItalic", size: size)
        } else if style.bold {
            selectedFont = font(named: "AvenirNext-DemiBold", size: size)
        } else if style.italic {
            selectedFont = font(named: "AvenirNext-Italic", size: size)
        } else {
            selectedFont = baseFont
        }

        var attributes: [NSAttributedString.Key: Any] = [
            kCTFontAttributeName as NSAttributedString.Key: selectedFont,
            kCTForegroundColorAttributeName as NSAttributedString.Key: style.link ? accentColor : (style.code ? codeTextColor : baseColor)
        ]

        if let linkDestination = style.linkDestination {
            attributes[kumaLinkAttribute] = linkDestination
        }

        if style.strikethrough {
            attributes[kumaStrikethroughAttribute] = true
        }

        return attributes
    }
}
