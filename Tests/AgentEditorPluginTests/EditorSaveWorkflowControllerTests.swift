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

    func testPerformSavePropagatesDidSaveNotificationOnSuccess() async {
        let controller = EditorSaveWorkflowController()
        let saveController = EditorSaveController()
        let saveStateController = EditorSaveStateController()
        let documentController = EditorDocumentController()
        _ = documentController.load(text: "demo")

        let fileURL = URL(fileURLWithPath: "/tmp/demo.swift")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data(), attributes: nil)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let expectation = expectation(description: "save success")
        var didSaveContent: String?

        controller.performSave(
            content: "saved",
            url: fileURL,
            verbose: false,
            logInfo: { _ in },
            logError: { _ in },
            setSaveState: { _ in },
            saveController: saveController,
            saveStateController: saveStateController,
            documentController: documentController,
            clearConflict: {},
            syncSession: {},
            scheduleSuccessClear: {
                expectation.fulfill()
            },
            notifyDidSave: { didSaveContent = $0 },
            setHasUnsavedChanges: { _ in }
        )

        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(didSaveContent, "saved")
    }
}
#endif
