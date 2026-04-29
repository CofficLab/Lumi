#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorSaveWorkflowControllerTests: XCTestCase {
    func testSaveNowIfNeededRunsOnlyWhenDirty() {
        let controller = EditorSaveWorkflowController()
        var ran = false

        controller.saveNowIfNeeded(
            hasUnsavedChanges: false,
            reason: "blur",
            fileName: "demo.swift",
            verbose: false,
            log: { _ in },
            runSave: { ran = true }
        )

        XCTAssertFalse(ran)

        controller.saveNowIfNeeded(
            hasUnsavedChanges: true,
            reason: "blur",
            fileName: "demo.swift",
            verbose: false,
            log: { _ in },
            runSave: { ran = true }
        )

        XCTAssertTrue(ran)
    }

    func testSaveNowSkipsWhileAlreadySaving() {
        let controller = EditorSaveWorkflowController()
        var ran = false

        controller.saveNow(saveState: .saving) {
            ran = true
        }

        XCTAssertFalse(ran)
    }
}
#endif
