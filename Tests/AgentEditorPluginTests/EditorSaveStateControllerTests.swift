#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorSaveStateControllerTests: XCTestCase {
    func testApplyMissingFileFailureSetsErrorState() {
        let controller = EditorSaveStateController()
        var saveState: EditorSaveState = .idle
        var scheduled = false

        controller.applyMissingFileFailure(
            scheduleSuccessClear: { scheduled = true },
            setSaveState: { saveState = $0 }
        )

        if case .error = saveState {
        } else {
            XCTFail("Expected error save state")
        }
        XCTAssertEqual(saveState, .error(EditorStatusMessageCatalog.fileNotFound()))
        XCTAssertTrue(scheduled)
    }

    func testApplySaveSuccessMarksSavedAndNotifiesDidSave() {
        let controller = EditorSaveStateController()
        let documentController = EditorDocumentController()
        _ = documentController.load(text: "before")

        var saveState: EditorSaveState = .idle
        var hasUnsavedChanges = true
        var didClearConflict = false
        var didSync = false
        var didSchedule = false
        var didSaveContent: String?

        controller.applySaveSuccess(
            content: "after",
            documentController: documentController,
            clearConflict: { didClearConflict = true },
            syncSession: { didSync = true },
            scheduleSuccessClear: { didSchedule = true },
            notifyDidSave: { didSaveContent = $0 },
            setHasUnsavedChanges: { hasUnsavedChanges = $0 },
            setSaveState: { saveState = $0 }
        )

        XCTAssertEqual(documentController.persistedContentSnapshot, "after")
        XCTAssertEqual(didSaveContent, "after")
        XCTAssertEqual(hasUnsavedChanges, false)
        XCTAssertEqual(saveState, .saved)
        XCTAssertTrue(didClearConflict)
        XCTAssertTrue(didSync)
        XCTAssertTrue(didSchedule)
    }
}
#endif
