import XCTest
@testable import EditorTextView

final class EditorTextViewWordUTF16Tests: XCTestCase {
    var textStorage: NSTextStorage!
    var layoutManager: TextLayoutManager!

    func selectionManager(_ text: String) -> TextSelectionManager {
        textStorage = NSTextStorage(string: text)
        layoutManager = TextLayoutManager(
            textStorage: textStorage,
            lineHeightMultiplier: 1.0,
            wrapLines: false,
            textView: NSView(),
            delegate: nil
        )
        return TextSelectionManager(
            layoutManager: layoutManager,
            textStorage: textStorage,
            textView: nil,
            delegate: nil
        )
    }

    func test_backwardWordOverEmojiReturnsFullUTF16Range() {
        let selectionManager = selectionManager("😀")
        let range = selectionManager.rangeOfSelection(
            from: 2, direction: .backward, destination: .word, decomposeCharacters: false
        )
        XCTAssertEqual(range, NSRange(location: 0, length: 2))
    }

    func test_forwardWordOverEmojiReturnsFullUTF16Range() {
        let selectionManager = selectionManager("😀")
        let range = selectionManager.rangeOfSelection(
            from: 0, direction: .forward, destination: .word, decomposeCharacters: false
        )
        XCTAssertEqual(range, NSRange(location: 0, length: 2))
    }

    func test_backwardWordOverTrailingEmojiInMixedString() {
        let selectionManager = selectionManager("ab😀")
        let range = selectionManager.rangeOfSelection(
            from: 4, direction: .backward, destination: .word, decomposeCharacters: false
        )
        XCTAssertEqual(range, NSRange(location: 0, length: 4))
    }

    func test_forwardWordOverLeadingEmojiInMixedString() {
        let selectionManager = selectionManager("😀cd")
        let range = selectionManager.rangeOfSelection(
            from: 0, direction: .forward, destination: .word, decomposeCharacters: false
        )
        XCTAssertEqual(range, NSRange(location: 0, length: 4))
    }
}