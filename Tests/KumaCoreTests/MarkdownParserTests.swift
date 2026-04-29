import XCTest
@testable import KumaCore

final class MarkdownParserTests: XCTestCase {
    func testParsesPracticalMarkdownBlocks() throws {
        let markdown = """
        ---
        title: Demo
        ---
        # Title

        > A quiet quote.
        > With two lines.

        1. First
          - Nested
        - [x] Done

        | Feature | Status |
        | --- | --- |
        | Tables | Done |

        ---
        """

        let blocks = parseMarkdown(markdown)

        XCTAssertEqual(blocks.first, .heading(level: 1, text: "Title"))
        XCTAssertTrue(blocks.contains(.blockquote("A quiet quote. With two lines.")))
        XCTAssertTrue(blocks.contains(.listItem(marker: .ordered(1), level: 0, text: "First")))
        XCTAssertTrue(blocks.contains(.listItem(marker: .unordered, level: 1, text: "Nested")))
        XCTAssertTrue(blocks.contains(.listItem(marker: .task(true), level: 0, text: "Done")))
        XCTAssertTrue(blocks.contains(.horizontalRule))

        let table = try XCTUnwrap(blocks.compactMap { block -> TableBlock? in
            if case .table(let table) = block { return table }
            return nil
        }.first)
        XCTAssertEqual(table.headers, ["Feature", "Status"])
        XCTAssertEqual(table.rows, [["Tables", "Done"]])
    }

    func testPreservesHardLineBreaksInsideParagraphs() {
        let blocks = parseMarkdown("""
        First line\\
        Second line
        """)

        XCTAssertEqual(blocks, [.paragraph("First line\nSecond line")])
    }
}
