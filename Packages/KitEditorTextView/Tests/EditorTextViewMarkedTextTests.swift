import XCTest
@testable import EditorTextView

final class EditorTextViewMarkedTextTests: XCTestCase {
    func test_markedTextSingleChar() {
        let textView = TextView(string: "")
        textView.selectionManager.setSelectedRange(.zero)

        textView.setMarkedText("´", selectedRange: .notFound, replacementRange: .notFound)
        XCTAssertEqual(textView.string, "´")

        textView.insertText("é", replacementRange: .notFound)
        XCTAssertEqual(textView.string, "é")
        XCTAssertEqual(textView.selectionManager.textSelections.map(\.range), [NSRange(location: 1, length: 0)])
    }

    func test_markedTextSingleCharInStrings() {
        let textView = TextView(string: "Lorem Ipsum")
        textView.selectionManager.setSelectedRange(NSRange(location: 5, length: 0))

        textView.setMarkedText("´", selectedRange: .notFound, replacementRange: .notFound)
        XCTAssertEqual(textView.string, "Lorem´ Ipsum")

        textView.insertText("é", replacementRange: .notFound)
        XCTAssertEqual(textView.string, "Loremé Ipsum")
        XCTAssertEqual(textView.selectionManager.textSelections.map(\.range), [NSRange(location: 6, length: 0)])
    }

    func test_markedTextReplaceSelection() {
        let textView = TextView(string: "ABCDE")
        textView.selectionManager.setSelectedRange(NSRange(location: 4, length: 1))

        textView.setMarkedText("´", selectedRange: .notFound, replacementRange: .notFound)
        XCTAssertEqual(textView.string, "ABCD´")

        textView.insertText("é", replacementRange: .notFound)
        XCTAssertEqual(textView.string, "ABCDé")
        XCTAssertEqual(textView.selectionManager.textSelections.map(\.range), [NSRange(location: 5, length: 0)])
    }

    func test_markedTextMultipleSelection() {
        let textView = TextView(string: "ABC")
        textView.selectionManager.setSelectedRanges([NSRange(location: 1, length: 0), NSRange(location: 2, length: 0)])

        textView.setMarkedText("´", selectedRange: .notFound, replacementRange: .notFound)
        XCTAssertEqual(textView.string, "A´B´C")

        textView.insertText("é", replacementRange: .notFound)
        XCTAssertEqual(textView.string, "AéBéC")
        XCTAssertEqual(
            textView.selectionManager.textSelections.map(\.range).sorted(by: { $0.location < $1.location }),
            [NSRange(location: 2, length: 0), NSRange(location: 4, length: 0)]
        )
    }

    func test_markedTextMultipleSelectionReplaceSelection() {
        let textView = TextView(string: "ABCDE")
        textView.selectionManager.setSelectedRanges([NSRange(location: 0, length: 1), NSRange(location: 4, length: 1)])

        textView.setMarkedText("´", selectedRange: .notFound, replacementRange: .notFound)
        XCTAssertEqual(textView.string, "´BCD´")

        textView.insertText("é", replacementRange: .notFound)
        XCTAssertEqual(textView.string, "éBCDé")
        XCTAssertEqual(
            textView.selectionManager.textSelections.map(\.range).sorted(by: { $0.location < $1.location }),
            [NSRange(location: 1, length: 0), NSRange(location: 5, length: 0)]
        )
    }

    func test_markedTextMultipleSelectionMultipleChar() {
        let textView = TextView(string: "ABCDE")
        textView.selectionManager.setSelectedRanges([NSRange(location: 0, length: 1), NSRange(location: 4, length: 1)])

        textView.setMarkedText("´", selectedRange: .notFound, replacementRange: .notFound)
        XCTAssertEqual(textView.string, "´BCD´")

        textView.setMarkedText("´´´", selectedRange: .notFound, replacementRange: .notFound)
        XCTAssertEqual(textView.string, "´´´BCD´´´")
        XCTAssertEqual(
            textView.selectionManager.textSelections.map(\.range).sorted(by: { $0.location < $1.location }),
            [NSRange(location: 3, length: 0), NSRange(location: 9, length: 0)]
        )

        textView.insertText("é", replacementRange: .notFound)
        XCTAssertEqual(textView.string, "éBCDé")
        XCTAssertEqual(
            textView.selectionManager.textSelections.map(\.range).sorted(by: { $0.location < $1.location }),
            [NSRange(location: 1, length: 0), NSRange(location: 5, length: 0)]
        )
    }

    func test_cancelMarkedText() {
        let textView = TextView(string: "")
        textView.selectionManager.setSelectedRange(.zero)

        textView.setMarkedText("´", selectedRange: .notFound, replacementRange: .notFound)
        XCTAssertEqual(textView.string, "´")

        // The NSTextInputContext performs the following actions when a marked text segment is ended w/o replacing the
        // marked text:
        textView.insertText("´", replacementRange: .notFound)
        textView.insertText("4", replacementRange: .notFound)

        XCTAssertEqual(textView.string, "´4")
        XCTAssertEqual(textView.selectionManager.textSelections.map(\.range), [NSRange(location: 2, length: 0)])
    }

    func test_cancelMarkedTextMultipleCursor() {
        let textView = TextView(string: "ABC")
        textView.selectionManager.setSelectedRanges([NSRange(location: 1, length: 0), NSRange(location: 2, length: 0)])

        textView.setMarkedText("´", selectedRange: .notFound, replacementRange: .notFound)
        XCTAssertEqual(textView.string, "A´B´C")

        // The NSTextInputContext performs the following actions when a marked text segment is ended w/o replacing the
        // marked text:
        textView.insertText("´", replacementRange: .notFound)
        textView.insertText("4", replacementRange: .notFound)

        XCTAssertEqual(textView.string, "A´4B´4C")
        XCTAssertEqual(
            textView.selectionManager.textSelections.map(\.range).sorted(by: { $0.location < $1.location }),
            [NSRange(location: 3, length: 0), NSRange(location: 6, length: 0)]
        )
    }

    func test_markedTextManagerUpdateForNewSelections() {
        let manager = MarkedTextManager()

        // No marked ranges: any selection cannot match, so an unmark is reported
        XCTAssertTrue(
            manager.updateForNewSelections(textSelections: [TextSelectionManager.TextSelection(range: .zero)])
        )

        manager.updateMarkedRanges(insertLength: 1, textSelections: [NSRange(location: 0, length: 0)])
        XCTAssertEqual(manager.markedRanges, [NSRange(location: 0, length: 1)])
        XCTAssertTrue(manager.hasMarkedText)

        // A selection still inside the marked range keeps the marked text
        XCTAssertFalse(
            manager.updateForNewSelections(textSelections: [TextSelectionManager.TextSelection(range: NSRange(location: 0, length: 1))])
        )

        // A selection that moved away from the marked range requires unmarking
        XCTAssertTrue(
            manager.updateForNewSelections(textSelections: [TextSelectionManager.TextSelection(range: NSRange(location: 5, length: 0))])
        )

        manager.removeAll()
        XCTAssertFalse(manager.hasMarkedText)
    }

    func test_markedTextManagerMarkedRangesInLine() {
        let manager = MarkedTextManager()
        manager.updateMarkedRanges(
            insertLength: 2,
            textSelections: [NSRange(location: 0, length: 0), NSRange(location: 10, length: 0)]
        )

        // Only the range intersecting the queried line is returned, relative to the line.
        // The two marked ranges land at (0,2) and (12,2); line (5,10) intersects only the latter.
        let marked = manager.markedRanges(in: NSRange(location: 5, length: 10))
        XCTAssertEqual(marked?.ranges, [NSRange(location: 7, length: 2)])
        XCTAssertNil(manager.markedRanges(in: NSRange(location: 3, length: 1)))
    }
}
