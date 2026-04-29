#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorInputCommandControllerTests: XCTestCase {
    func testLineEditUsesLanguageAwareCommentPrefix() {
        let controller = EditorInputCommandController()

        let result = controller.lineEditResult(
            kind: .toggleLineComment,
            text: "print(\"hi\")\n",
            selections: [NSRange(location: 0, length: 0)],
            languageId: "python"
        )

        XCTAssertEqual(result?.replacementText, "# print(\"hi\")\n")
    }

    func testCursorMotionPlanForDeleteWordLeftBuildsTransaction() {
        let controller = EditorInputCommandController()

        let plan = controller.cursorMotionPlan(
            kind: .deleteWordLeft,
            text: "hello world",
            currentLocation: 11,
            currentRange: NSRange(location: 11, length: 0)
        )

        guard case .transaction(let transaction)? = plan else {
            return XCTFail("Expected transaction plan")
        }

        XCTAssertEqual(transaction.replacements.first?.range.location, 6)
        XCTAssertEqual(transaction.replacements.first?.range.length, 5)
        XCTAssertEqual(transaction.replacements.first?.text, "")
        XCTAssertEqual(transaction.updatedSelections?.first?.range.location, 6)
    }

    func testCursorMotionPlanForWordRightSelectBuildsExpandedSelection() {
        let controller = EditorInputCommandController()

        let plan = controller.cursorMotionPlan(
            kind: .wordRightSelect,
            text: "hello world",
            currentLocation: 0,
            currentRange: NSRange(location: 0, length: 0)
        )

        guard case .selections(let ranges)? = plan else {
            return XCTFail("Expected selection plan")
        }

        XCTAssertEqual(ranges, [NSRange(location: 0, length: 5)])
    }
}
#endif
