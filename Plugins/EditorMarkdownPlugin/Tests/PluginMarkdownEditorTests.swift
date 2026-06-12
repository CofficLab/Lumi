import Foundation
import Testing
import EditorSource
@testable import EditorMarkdownPlugin

@Test func highlightsMarkdownOutsideFencedCodeBlocks() {
    let markdown = """
    # Heading

    ```swift
    # Not a heading
    **not bold**
    ```

    **bold**
    """

    let highlights = MarkdownHighlightScanner.highlights(
        in: markdown,
        visibleRange: NSRange(location: 0, length: (markdown as NSString).length)
    )

    #expect(highlights.containsHighlight(for: "# Heading", capture: .keyword, in: markdown))
    #expect(highlights.containsHighlight(for: "```swift\n# Not a heading\n**not bold**\n```", capture: .string, in: markdown))
    #expect(highlights.containsHighlight(for: "**bold**", capture: .type, in: markdown))
    #expect(!highlights.containsHighlight(for: "# Not a heading", capture: .keyword, in: markdown))
    #expect(!highlights.containsHighlight(for: "**not bold**", capture: .type, in: markdown))
}

@Test func highlightsUnclosedFencedCodeBlockThroughDocumentEnd() {
    let markdown = """
    Intro

    ~~~
    # Not a heading
    """

    let highlights = MarkdownHighlightScanner.highlights(
        in: markdown,
        visibleRange: NSRange(location: 0, length: (markdown as NSString).length)
    )

    #expect(highlights.containsHighlight(for: "~~~\n# Not a heading", capture: .string, in: markdown))
    #expect(!highlights.containsHighlight(for: "# Not a heading", capture: .keyword, in: markdown))
}

private extension [HighlightRange] {
    func containsHighlight(for needle: String, capture: CaptureName, in text: String) -> Bool {
        let fullText = text as NSString
        let expectedRange = fullText.range(of: needle)
        guard expectedRange.location != NSNotFound else { return false }

        return contains { highlight in
            highlight.capture == capture
                && NSIntersectionRange(highlight.range, expectedRange) == expectedRange
        }
    }
}
