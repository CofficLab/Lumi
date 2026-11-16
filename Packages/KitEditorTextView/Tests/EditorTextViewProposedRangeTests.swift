import XCTest
@testable import EditorTextView

final class EditorTextViewProposedRangeTests: XCTestCase {
    func test_proposedRangeCompletelyOutsideReturnsNil() {
        let textView = TextView(string: "abc")
        let result = textView.attributedSubstring(forProposedRange: NSRange(location: 10, length: 1), actualRange: nil)
        XCTAssertNil(result)
    }

    func test_proposedRangeStartingAtDocumentEndReturnsNil() {
        let textView = TextView(string: "abc")
        let result = textView.attributedSubstring(forProposedRange: NSRange(location: 3, length: 1), actualRange: nil)
        XCTAssertNil(result)
    }

    func test_proposedRangePartialIntersectionReturnsIntersection() {
        let textView = TextView(string: "abc")
        var actual = NSRange(location: NSNotFound, length: 0)
        let result = textView.attributedSubstring(forProposedRange: NSRange(location: 2, length: 5), actualRange: &actual)
        XCTAssertEqual(result?.string, "c")
        XCTAssertEqual(actual, NSRange(location: 2, length: 1))
    }

    func test_proposedRangeFullyInsideReturnsFullSubstring() {
        let textView = TextView(string: "abc")
        var actual = NSRange(location: NSNotFound, length: 0)
        let result = textView.attributedSubstring(forProposedRange: NSRange(location: 0, length: 3), actualRange: &actual)
        XCTAssertEqual(result?.string, "abc")
        XCTAssertEqual(actual, NSRange(location: 0, length: 3))
    }

    func test_proposedRangeZeroLengthInsideReturnsCharacterAtCaret() {
        let textView = TextView(string: "abc")
        let result = textView.attributedSubstring(forProposedRange: NSRange(location: 1, length: 0), actualRange: nil)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.string, "b")
    }
}