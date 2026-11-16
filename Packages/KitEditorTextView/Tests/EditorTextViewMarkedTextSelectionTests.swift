import XCTest
@testable import EditorTextView

// 回归 #576：setMarkedText 必须采用输入法给出的 selectedRange（相对插入串起点），而非一律跳到组合末尾。
final class EditorTextViewMarkedTextSelectionTests: XCTestCase {
    func test_setMarkedTextHonorsRelativeSelectedRange() {
        let textView = TextView(string: "")
        textView.selectionManager.setSelectedRange(.zero)

        textView.setMarkedText("abc", selectedRange: NSRange(location: 1, length: 1), replacementRange: .notFound)

        XCTAssertEqual(textView.string, "abc")
        XCTAssertEqual(textView.selectionManager.textSelections.map(\.range), [NSRange(location: 1, length: 1)])
    }

    func test_setMarkedTextCaretAtStartFromSelectedRange() {
        let textView = TextView(string: "")
        textView.selectionManager.setSelectedRange(.zero)

        textView.setMarkedText("abc", selectedRange: NSRange(location: 0, length: 0), replacementRange: .notFound)

        XCTAssertEqual(textView.string, "abc")
        XCTAssertEqual(textView.selectionManager.textSelections.map(\.range), [NSRange(location: 0, length: 0)])
    }

    func test_setMarkedTextNotFoundSelectedRangeFallsBackToEnd() {
        let textView = TextView(string: "")
        textView.selectionManager.setSelectedRange(.zero)

        textView.setMarkedText("abc", selectedRange: .notFound, replacementRange: .notFound)

        XCTAssertEqual(textView.string, "abc")
        XCTAssertEqual(textView.selectionManager.textSelections.map(\.range), [NSRange(location: 3, length: 0)])
    }

    func test_setMarkedTextSelectedRangeMapsOntoExistingMarkedText() {
        let textView = TextView(string: "")
        textView.selectionManager.setSelectedRange(.zero)

        textView.setMarkedText("abc", selectedRange: NSRange(location: 3, length: 0), replacementRange: .notFound)
        textView.setMarkedText("abcd", selectedRange: NSRange(location: 2, length: 1), replacementRange: .notFound)

        XCTAssertEqual(textView.string, "abcd")
        XCTAssertEqual(textView.selectionManager.textSelections.map(\.range), [NSRange(location: 2, length: 1)])
    }
}