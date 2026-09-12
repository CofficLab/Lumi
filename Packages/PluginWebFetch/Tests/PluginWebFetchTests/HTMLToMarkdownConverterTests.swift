import Foundation
import Testing
@testable import PluginWebFetch

@Suite("HTML to Markdown conversion")
struct HTMLToMarkdownConverterTests {
    @Test("removes executable content and decodes named and numeric entities")
    func removesUnwantedContentAndDecodesEntities() {
        let html = """
        <html><head><style>.hidden { display: none }</style><script>alert('hidden')</script></head>
        <body><h1>Fish &amp; Chips</h1><p>Use &lt;T&gt;, &#x26;, and &#60;value&#62;.</p></body></html>
        """

        let markdown = HTMLToMarkdownConverter.convert(html)

        #expect(markdown.contains("# Fish & Chips"))
        #expect(markdown.contains("Use <T>, &, and <value>."))
        #expect(markdown.contains("hidden") == false)
    }

    @Test("resolves relative and protocol-relative links and images")
    func resolvesDocumentURLs() {
        let baseURL = URL(string: "https://example.com/docs/page.html")!
        let html = #"<p><a href="../guide?q=1&amp;x=2"> Read <strong>the guide</strong> </a><img src="//cdn.example.com/cover.png" alt="Cover" /></p>"#

        let markdown = HTMLToMarkdownConverter.convert(html, baseURL: baseURL)

        #expect(markdown.contains("[Read the guide](https://example.com/guide?q=1&x=2)"))
        #expect(markdown.contains("![Cover](https://cdn.example.com/cover.png)"))
    }

    @Test("converts lists, code, blockquotes, and escaped table cells")
    func convertsStructuredContent() {
        let html = """
        <ul><li>Alpha</li><li><strong>Beta</strong></li></ul>
        <ol start="3"><li>Third</li><li>Fourth</li></ol>
        <pre><code>let count = 2 &amp;&amp; 3</code></pre>
        <blockquote><p>Quoted text</p></blockquote>
        <table><tr><th>Name</th><th>Score</th></tr><tr><td>Ada | B</td><td>10</td></tr></table>
        """

        let markdown = HTMLToMarkdownConverter.convert(html)

        #expect(markdown.contains("- Alpha"))
        #expect(markdown.contains("- **Beta**"))
        #expect(markdown.contains("3. Third"))
        #expect(markdown.contains("4. Fourth"))
        #expect(markdown.contains("```\nlet count = 2 && 3\n```"))
        #expect(markdown.contains("> Quoted text"))
        #expect(markdown.contains("| Ada \\| B | 10 |"))
    }

    @Test("normalizes an unclosed list and truncates oversized content")
    func handlesMalformedAndOversizedHTML() {
        let malformed = HTMLToMarkdownConverter.convert("<ul><li>One</li><li>Two</li>")
        #expect(malformed.contains("One"))
        #expect(malformed.contains("Two"))

        let oversized = HTMLToMarkdownConverter.convert(String(repeating: "x", count: 100_001))
        #expect(oversized.hasSuffix("[Content truncated due to length...]"))
        #expect(oversized.count <= HTMLToMarkdownConverter.maxContentLength + 40)
    }
}
