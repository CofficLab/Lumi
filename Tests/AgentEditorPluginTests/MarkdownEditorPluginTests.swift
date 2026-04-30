#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class MarkdownEditorPluginTests: XCTestCase {
    func testMarkdownPluginRegistersHighlightProvider() {
        let registry = EditorExtensionRegistry()
        let plugin = MarkdownEditorPlugin()

        plugin.registerEditorExtensions(into: registry)

        let providers = registry.highlightProviders(for: "markdown")
        XCTAssertEqual(providers.count, 1)
        XCTAssertTrue(providers.first is MarkdownHighlightProvider)
    }

    func testMarkdownHighlightScannerFindsBlockAndInlineSyntax() {
        let text = """
        # Title
        - item with `code`
        > quote
        [link](https://example.com)
        """
        let highlights = MarkdownHighlightScanner.highlights(
            in: text,
            visibleRange: NSRange(location: 0, length: (text as NSString).length)
        )

        XCTAssertTrue(highlights.contains(where: { $0.capture == .keyword && nsSubstring(text, $0.range).contains("# Title") }))
        XCTAssertTrue(highlights.contains(where: { $0.capture == .keyword && nsSubstring(text, $0.range) == "- " }))
        XCTAssertTrue(highlights.contains(where: { $0.capture == .string && nsSubstring(text, $0.range) == "`code`" }))
        XCTAssertTrue(highlights.contains(where: { $0.capture == .comment && nsSubstring(text, $0.range).contains("> quote") }))
        XCTAssertTrue(highlights.contains(where: { $0.capture == .function && nsSubstring(text, $0.range).contains("[link]") }))
    }

    private func nsSubstring(_ text: String, _ range: NSRange) -> String {
        (text as NSString).substring(with: range)
    }
}
#endif
