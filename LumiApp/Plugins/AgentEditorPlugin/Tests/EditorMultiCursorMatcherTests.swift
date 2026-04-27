#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorMultiCursorMatcherTests: XCTestCase {
    func testNormalizedRangeClampsToDocumentBounds() {
        let text = "alpha beta" as NSString

        let range = EditorMultiCursorMatcher.normalizedRange(
            NSRange(location: 50, length: 10),
            in: text
        )

        XCTAssertEqual(range.location, text.length)
        XCTAssertEqual(range.length, 0)
    }

    func testResolvedBaseSelectionExpandsCaretToWord() {
        let text = "alpha beta_gamma" as NSString

        let selection = EditorMultiCursorMatcher.resolvedBaseSelection(
            from: NSRange(location: 8, length: 0),
            in: text
        )

        XCTAssertEqual(selection, MultiCursorSelection(location: 6, length: 10))
    }

    func testResolvedBaseSelectionReturnsExplicitSelectionAsIs() {
        let text = "alpha beta" as NSString

        let selection = EditorMultiCursorMatcher.resolvedBaseSelection(
            from: NSRange(location: 1, length: 4),
            in: text
        )

        XCTAssertEqual(selection, MultiCursorSelection(location: 1, length: 4))
    }

    func testRangesMatchesWholeWordsForIdentifierQueries() {
        let text = "foo foo_bar foo foo1 foo" as NSString

        let matches = EditorMultiCursorMatcher.ranges(of: "foo", in: text)

        XCTAssertEqual(matches, [
            .init(location: 0, length: 3),
            .init(location: 12, length: 3),
            .init(location: 21, length: 3),
        ])
    }

    func testSelectionTextReturnsSubstringForValidSelection() {
        let text = "hello world" as NSString

        let value = EditorMultiCursorMatcher.selectionText(
            for: .init(location: 6, length: 5),
            in: text
        )

        XCTAssertEqual(value, "world")
    }

    func testSearchContextBuildsBaseSelectionAndQuery() {
        let text = "foo bar_baz" as NSString

        let context = EditorMultiCursorMatcher.searchContext(
            from: NSRange(location: 5, length: 0),
            in: text
        )

        XCTAssertEqual(
            context,
            EditorMultiCursorSearchContext(
                baseSelection: .init(location: 4, length: 7),
                query: "bar_baz"
            )
        )
    }
}
#endif
