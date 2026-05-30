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

    func testConvertsLinksAndImagesWithFlexibleAttributeSyntax() {
        let html = """
        <a class="button" href='/docs/start'>
            <span>Start Guide</span>
        </a>
        <img alt='Hero' loading="lazy" src="/hero.png">
        <img src=/logo.svg>
        """

        let markdown = HTMLToMarkdownConverter.convert(
            html,
            baseURL: URL(string: "https://example.com/base/")
        )

        XCTAssertTrue(markdown.contains("[Start Guide](https://example.com/docs/start)"))
        XCTAssertTrue(markdown.contains("![Hero](https://example.com/hero.png)"))
        XCTAssertTrue(markdown.contains("![image](https://example.com/logo.svg)"))
    }

    func testDecodesDecimalAndHexNumericEntities() {
        let html = "<p>Symbols: &#169; &#x1F680; &#X2713;</p>"

        let markdown = HTMLToMarkdownConverter.convert(html)

        XCTAssertTrue(markdown.contains("Symbols: © 🚀 ✓"))
        XCTAssertFalse(markdown.contains("&#x1F680;"))
    }

    func testPreservesEscapedAngleBracketsInTextAndCode() {
        let html = """
        <p>Use &lt;section&gt; when 1 &#60; 2 and 3 &#x3E; 2.</p>
        <pre><code>&lt;div class=&quot;card&quot;&gt;Hi&lt;/div&gt;</code></pre>
        <p>Real <span>HTML</span> tags are removed.</p>
        """

        let markdown = HTMLToMarkdownConverter.convert(html)

        XCTAssertTrue(markdown.contains("Use <section> when 1 < 2 and 3 > 2."))
        XCTAssertTrue(markdown.contains("```\n<div class=\"card\">Hi</div>\n```"))
        XCTAssertTrue(markdown.contains("Real HTML tags are removed."))
        XCTAssertFalse(markdown.contains("<span>"))
    }

    func testRemovesMultilineUnwantedTags() {
        let html = """
        <script>
        window.noisy = true;
        </script>
        <style>
        body { color: red; }
        </style>
        <!--
        hidden comment
        -->
        <p>Visible text</p>
        """

        let markdown = HTMLToMarkdownConverter.convert(html)

        XCTAssertTrue(markdown.contains("Visible text"))
        XCTAssertFalse(markdown.contains("window.noisy"))
        XCTAssertFalse(markdown.contains("color: red"))
        XCTAssertFalse(markdown.contains("hidden comment"))
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

    func testPreservesOrderedListStartAttribute() {
        let html = """
        <ol start="5">
        <li>Open Settings</li>
        <li>Enable the plugin</li>
        </ol>
        """

        let markdown = HTMLToMarkdownConverter.convert(html)

        XCTAssertTrue(markdown.contains("5. Open Settings"))
        XCTAssertTrue(markdown.contains("6. Enable the plugin"))
        XCTAssertFalse(markdown.contains("1. Open Settings"))
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

    func testEscapesPipeCharactersInTableCells() {
        let html = """
        <table>
        <tr><th>Pattern</th><th>Description</th></tr>
        <tr><td>foo|bar</td><td>Matches A | B</td></tr>
        </table>
        """

        let markdown = HTMLToMarkdownConverter.convert(html)

        XCTAssertTrue(markdown.contains("| Pattern | Description |"))
        XCTAssertTrue(markdown.contains("| foo\\|bar | Matches A \\| B |"))
        XCTAssertFalse(markdown.contains("| foo|bar | Matches A | B |"))
    }

    func testConvertsMultilinePreCodeBlocksBeforeInlineCode() {
        let html = """
        <pre><code>let x = 1
        print(x)</code></pre>
        <p>Use <code>inline()</code>.</p>
        """

        let markdown = HTMLToMarkdownConverter.convert(html)

        XCTAssertTrue(markdown.contains("```\nlet x = 1\nprint(x)\n```"))
        XCTAssertTrue(markdown.contains("Use `inline()`."))
        XCTAssertFalse(markdown.contains("`let x = 1"))
    }

    func testConvertsMultilineBlockquotes() {
        let html = """
        <blockquote>
        <p>First quoted line</p>
        <p>Second quoted line</p>
        </blockquote>
        <p>Outside quote</p>
        """

        let markdown = HTMLToMarkdownConverter.convert(html)

        XCTAssertTrue(markdown.contains("> First quoted line"))
        XCTAssertTrue(markdown.contains("> Second quoted line"))
        XCTAssertTrue(markdown.contains("Outside quote"))
        XCTAssertFalse(markdown.contains("<blockquote>"))
    }

    func testConvertsCompactBlockquoteParagraphsAsSeparateLines() {
        let html = "<blockquote><p>First quoted line</p><p>Second quoted line</p></blockquote>"

        let markdown = HTMLToMarkdownConverter.convert(html)

        XCTAssertTrue(markdown.contains("> First quoted line\n> Second quoted line"))
        XCTAssertFalse(markdown.contains("First quoted lineSecond quoted line"))
    }

    func testTruncatesVeryLargeContent() {
        let html = "<p>" + String(repeating: "a", count: HTMLToMarkdownConverter.maxContentLength + 100) + "</p>"

        let markdown = HTMLToMarkdownConverter.convert(html)

        XCTAssertLessThanOrEqual(markdown.count, HTMLToMarkdownConverter.maxContentLength + 40)
        XCTAssertTrue(markdown.contains("[Content truncated due to length...]"))
    }
}
