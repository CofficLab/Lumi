#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorExternalFileWorkflowControllerTests: XCTestCase {
    func testReloadDecisionPrefersConflictWhenDirty() {
        let controller = EditorExternalFileWorkflowController()
        let date = Date()

        let decision = controller.reloadDecision(
            newContent: "new",
            currentContent: "old",
            currentModDate: date,
            hasUnsavedChanges: true
        )

        guard case let .registerConflict(content, modificationDate) = decision else {
            return XCTFail("Expected conflict decision")
        }
        XCTAssertEqual(content, "new")
        XCTAssertEqual(modificationDate, date)
    }
}
#endif
