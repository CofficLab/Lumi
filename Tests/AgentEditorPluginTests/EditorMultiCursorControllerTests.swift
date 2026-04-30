#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorMultiCursorControllerTests: XCTestCase {
    func testSummaryTextUsesCursorCount() {
        let controller = EditorMultiCursorController()
        let single = MultiCursorState(primary: .init(location: 0, length: 0), secondary: [])
        let multi = MultiCursorState(
            primary: .init(location: 0, length: 1),
            secondary: [.init(location: 4, length: 1)]
        )

        XCTAssertEqual(controller.summaryText(for: single), "1")
        XCTAssertEqual(controller.summaryText(for: multi), "2" + String(localized: " cursors", table: "LumiEditor"))
    }

    func testReplacementResultBuildsTransactionAndUpdatedSelections() {
        let controller = EditorMultiCursorController()
        let selections = [
            MultiCursorSelection(location: 0, length: 3),
            MultiCursorSelection(location: 4, length: 3)
        ]

        let outcome = controller.replacementResult(
            text: "foo foo",
            selections: selections,
            replacement: "bar"
        )

        XCTAssertEqual(outcome.result.text, "bar bar")
        XCTAssertEqual(outcome.transaction.updatedSelections?.count, 2)
    }

    func testStateFromSelectionsBuildsCanonicalPrimaryAndSecondary() {
        let controller = EditorMultiCursorController()
        let selections = [
            MultiCursorSelection(location: 10, length: 2),
            MultiCursorSelection(location: 2, length: 1)
        ]

        let state = controller.state(from: selections)

        XCTAssertEqual(state.primary.location, 2)
        XCTAssertEqual(state.all.count, 2)
    }

    func testLogHelpersRenderStableSummaries() {
        let controller = EditorMultiCursorController()
        let selections = [
            MultiCursorSelection(location: 2, length: 1),
            MultiCursorSelection(location: 10, length: 2)
        ]

        let stateMessage = controller.stateLogMessage(
            action: "setSelections",
            selections: selections,
            note: "incomingCount=2"
        )
        let inputMessage = controller.inputLogMessage(
            action: "insertText",
            textViewSelections: [NSRange(location: 2, length: 1)],
            note: nil
        )

        XCTAssertTrue(stateMessage.contains("incomingCount=2"))
        XCTAssertTrue(stateMessage.contains("#0{loc=2,len=1}"))
        XCTAssertTrue(inputMessage.contains("{2, 1}"))
    }

    func testMultiCursorStateExposesPrimaryAndSecondarySelections() {
        let state = MultiCursorState(
            primary: .init(location: 2, length: 0),
            secondary: [
                .init(location: 6, length: 4),
                .init(location: 12, length: 0)
            ]
        )

        XCTAssertTrue(state.isEnabled)
        XCTAssertEqual(state.all.count, 3)
        XCTAssertEqual(state.secondary.count, 2)
    }
}
#endif
