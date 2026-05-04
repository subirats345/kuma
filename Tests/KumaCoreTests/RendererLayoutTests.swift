import CoreGraphics
import CoreText
import Foundation
import XCTest
@testable import KumaCore

final class RendererLayoutTests: XCTestCase {
    func testLongHeadingsAdvanceByWrappedLines() throws {
        var renderer = try makeRenderer()
        renderer.beginPage(startY: firstPageStartY)
        let startY = renderer.y
        let heading = Array(repeating: "A heading with enough words to require wrapping", count: 5).joined(separator: " ")

        renderer.drawHeading(level: 1, text: heading, previous: nil)
        renderer.endPage()

        XCTAssertGreaterThan(renderer.y - startY, 50)
    }

    func testWrappedHeadingLinesStayWithinHeadingWidth() throws {
        let renderer = try makeRenderer()
        let heading = Array(repeating: "Long headings should wrap instead of crossing the right margin", count: 4).joined(separator: " ")
        let attributed = renderer.makeHeadingAttributed(heading, level: 1)
        let ranges = renderer.wrappedLineRanges(attributed, width: headingWidth)

        XCTAssertGreaterThan(ranges.count, 1)
        for range in ranges where range.length > 0 {
            let substring = attributed.attributedSubstring(from: NSRange(location: range.location, length: range.length))
            let line = CTLineCreateWithAttributedString(substring)
            let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            XCTAssertLessThanOrEqual(width, headingWidth + 0.5)
        }
    }

    private func makeRenderer() throws -> Renderer {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
            throw TestFailure("Could not create PDF data consumer")
        }
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw TestFailure("Could not create PDF context")
        }

        return Renderer(
            context: context,
            inputDirectory: URL(fileURLWithPath: NSTemporaryDirectory()),
            bodyFont: font(named: defaultBodyFontName, size: 11),
            headingFont: font(named: defaultHeadingFontName, size: 18),
            codeFont: font(named: defaultCodeFontName, size: 9.5)
        )
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
