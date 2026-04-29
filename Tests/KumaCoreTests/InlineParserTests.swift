import XCTest
@testable import KumaCore

final class InlineParserTests: XCTestCase {
    func testParsesPracticalInlineMarkdown() throws {
        let runs = parseInlineRuns("A **bold** *italic* ***both*** `code` [link](https://example.com) ~~gone~~ \\*literal\\*")

        XCTAssertEqual(runs.map(\.text).joined(), "A bold italic both code link gone *literal*")
        XCTAssertTrue(try XCTUnwrap(runs.first { $0.text == "bold" }).style.bold)
        XCTAssertTrue(try XCTUnwrap(runs.first { $0.text == "italic" }).style.italic)

        let both = try XCTUnwrap(runs.first { $0.text == "both" })
        XCTAssertTrue(both.style.bold)
        XCTAssertTrue(both.style.italic)

        XCTAssertTrue(try XCTUnwrap(runs.first { $0.text == "code" }).style.code)
        XCTAssertTrue(try XCTUnwrap(runs.first { $0.text == "link" }).style.link)
        XCTAssertTrue(try XCTUnwrap(runs.first { $0.text == "gone" }).style.strikethrough)
    }

    func testAutolinksUseLinkStyleWithoutAngleBrackets() throws {
        let runs = parseInlineRuns("Visit <https://example.com> or <hello@example.com>")

        XCTAssertEqual(runs.map(\.text).joined(), "Visit https://example.com or hello@example.com")
        XCTAssertEqual(runs.filter(\.style.link).map(\.text), ["https://example.com", "hello@example.com"])
    }
}
