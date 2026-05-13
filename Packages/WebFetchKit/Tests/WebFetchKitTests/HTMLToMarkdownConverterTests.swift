import XCTest
@testable import WebFetchKit

final class HTMLToMarkdownConverterTests: XCTestCase {
    func testConvertsCoreHTMLElements() {
        let html = """
        <html><body>
        <h1>Title &amp; More</h1>
        <p>Hello <strong>bold</strong> and <em>italic</em>.</p>
        <a href="/docs">Docs</a>
        <img src="/image.png" alt="Preview">
        </body></html>
        """

        let markdown = HTMLToMarkdownConverter.convert(
            html,
            baseURL: URL(string: "https://example.com/base/")
        )

        XCTAssertTrue(markdown.contains("# Title & More"))
        XCTAssertTrue(markdown.contains("**bold**"))
        XCTAssertTrue(markdown.contains("*italic*"))
        XCTAssertTrue(markdown.contains("[Docs](https://example.com/docs)"))
        XCTAssertTrue(markdown.contains("![Preview](https://example.com/image.png)"))
    }

    func testConvertsListsWithoutCrashingOnMalformedListContent() {
        let html = """
        <ol></li><li>First</li><li><span>Second</span></li></ol>
        <ul><li>Loose</li><li><strong>Bold</strong></li></ul>
        """

        let markdown = HTMLToMarkdownConverter.convert(html)

        XCTAssertTrue(markdown.contains("1. First"))
        XCTAssertTrue(markdown.contains("2. Second"))
        XCTAssertTrue(markdown.contains("- Loose"))
        XCTAssertTrue(markdown.contains("- **Bold**"))
    }

    func testConvertsTablesAndCodeBlocks() {
        let html = """
        <table>
        <tr><th>Name</th><th>Value</th></tr>
        <tr><td>Alpha</td><td>1</td></tr>
        </table>
        <pre><code>let x = 1</code></pre>
        """

        let markdown = HTMLToMarkdownConverter.convert(html)

        XCTAssertTrue(markdown.contains("| Name | Value |"))
        XCTAssertTrue(markdown.contains("| --- | --- |"))
        XCTAssertTrue(markdown.contains("| Alpha | 1 |"))
        XCTAssertTrue(markdown.contains("```"))
        XCTAssertTrue(markdown.contains("let x = 1"))
    }

    func testTruncatesVeryLargeContent() {
        let html = "<p>" + String(repeating: "a", count: HTMLToMarkdownConverter.maxContentLength + 100) + "</p>"

        let markdown = HTMLToMarkdownConverter.convert(html)

        XCTAssertLessThanOrEqual(markdown.count, HTMLToMarkdownConverter.maxContentLength + 40)
        XCTAssertTrue(markdown.contains("[Content truncated due to length...]"))
    }
}
