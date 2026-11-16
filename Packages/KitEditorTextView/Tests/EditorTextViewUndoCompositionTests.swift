import XCTest
@testable import EditorTextView

// 回归 #577：IME 组合期间 disable() 必须真正阻止 registerMutation，未提交的中间态不得进入撤销历史。
final class EditorTextViewUndoCompositionTests: XCTestCase {
    func test_compositionDoesNotRegisterUndoMutations() {
        let textView = TextView(string: "")
        textView.selectionManager.setSelectedRange(.zero)

        textView.setMarkedText("n", selectedRange: .notFound, replacementRange: .notFound)
        textView.setMarkedText("ni", selectedRange: .notFound, replacementRange: .notFound)

        XCTAssertEqual(textView.string, "ni")
        XCTAssertEqual(textView._undoManager?.undoCount, 0)
    }

    func test_undoAfterCommitDoesNotRestoreComposition() {
        let textView = TextView(string: "")
        textView.selectionManager.setSelectedRange(.zero)

        textView.setMarkedText("n", selectedRange: .notFound, replacementRange: .notFound)
        textView.setMarkedText("ni", selectedRange: .notFound, replacementRange: .notFound)
        textView.insertText("ni", replacementRange: .notFound)

        XCTAssertEqual(textView.string, "ni")
        XCTAssertEqual(textView._undoManager?.undoCount, 1)

        textView._undoManager?.undo()
        XCTAssertEqual(textView.string, "")

        textView._undoManager?.undo()
        XCTAssertEqual(textView.string, "")
    }

    func test_normalInsertStillRegistersUndo() {
        let textView = TextView(string: "")
        textView.selectionManager.setSelectedRange(.zero)

        textView.insertText("hello", replacementRange: .notFound)

        XCTAssertEqual(textView.string, "hello")
        XCTAssertEqual(textView._undoManager?.undoCount, 1)

        textView._undoManager?.undo()
        XCTAssertEqual(textView.string, "")
    }
}