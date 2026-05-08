import Foundation
import Testing
@testable import EditorKernelCore

@Suite("EditorStatusMessageCatalog Tests")
struct EditorStatusMessageCatalogTests {

    @Test
    func externalFileChangedOnDiskWithFileName() {
        let message = EditorStatusMessageCatalog.externalFileChangedOnDisk(fileName: "test.swift")
        #expect(message == "test.swift changed on disk. Reload or keep the editor version.")
    }

    @Test
    func externalFileChangedOnDiskWithoutFileName() {
        let message = EditorStatusMessageCatalog.externalFileChangedOnDisk(fileName: nil)
        #expect(message == "File changed on disk. Reload or keep the editor version.")
    }

    @Test
    func externalFileChangedOnDiskWithEmptyFileName() {
        let message = EditorStatusMessageCatalog.externalFileChangedOnDisk(fileName: "")
        #expect(message == "File changed on disk. Reload or keep the editor version.")
    }

    @Test
    func externalFileChangedOnDiskForProjectFile() {
        let message = EditorStatusMessageCatalog.externalFileChangedOnDisk(isProjectFile: true)
        #expect(message == "project.pbxproj changed on disk. Prefer the project version or keep the Lumi version before saving again.")
    }

    @Test
    func externalFileChangedOnDiskForProjectFileWithFileName() {
        // Project file flag overrides fileName
        let message = EditorStatusMessageCatalog.externalFileChangedOnDisk(fileName: "test.swift", isProjectFile: true)
        #expect(message == "project.pbxproj changed on disk. Prefer the project version or keep the Lumi version before saving again.")
    }

    @Test
    func projectFileSaveConfirmation() {
        let message = EditorStatusMessageCatalog.projectFileSaveConfirmation(fileName: "project.pbxproj")
        #expect(message == "project.pbxproj is an Xcode project file. Saving from Lumi can conflict with concurrent Xcode edits.")
    }

    @Test
    func saveFailedWithDetail() {
        let message = EditorStatusMessageCatalog.saveFailed("Permission denied")
        #expect(message == "Save failed. Permission denied")
    }

    @Test
    func saveFailedWithoutDetail() {
        let message = EditorStatusMessageCatalog.saveFailed(nil)
        #expect(message == "Save failed. Check file permissions or path availability.")
    }

    @Test
    func saveFailedWithEmptyDetail() {
        let message = EditorStatusMessageCatalog.saveFailed("")
        #expect(message == "Save failed. Check file permissions or path availability.")
    }

    @Test
    func fileNotFound() {
        let message = EditorStatusMessageCatalog.fileNotFound()
        #expect(message == "Save failed. The file no longer exists on disk.")
    }

    @Test
    func formattingUnavailable() {
        let message = EditorStatusMessageCatalog.formattingUnavailable("LSP not available")
        #expect(message == "Formatting unavailable. LSP not available")
    }

    @Test
    func languageFeatureUnavailable() {
        let message = EditorStatusMessageCatalog.languageFeatureUnavailable(
            operation: "Go to definition",
            reason: "LSP server not running"
        )
        #expect(message == "Go to definition unavailable. LSP server not running")
    }
}

@Suite("EditorSaveState Tests")
struct EditorSaveStateTests {

    @Test
    func idleStateIcon() {
        #expect(EditorSaveState.idle.icon == "checkmark.circle")
    }

    @Test
    func editingStateIcon() {
        #expect(EditorSaveState.editing.icon == "pencil.circle")
    }

    @Test
    func savingStateIcon() {
        #expect(EditorSaveState.saving.icon == "arrow.triangle.2.circlepath")
    }

    @Test
    func savedStateIcon() {
        #expect(EditorSaveState.saved.icon == "checkmark.circle.fill")
    }

    @Test
    func conflictStateIcon() {
        #expect(EditorSaveState.conflict("test").icon == "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
    }

    @Test
    func errorStateIcon() {
        #expect(EditorSaveState.error("test").icon == "exclamationmark.triangle.fill")
    }

    @Test
    func stateEquality() {
        #expect(EditorSaveState.idle == EditorSaveState.idle)
        #expect(EditorSaveState.editing == EditorSaveState.editing)
        #expect(EditorSaveState.saving == EditorSaveState.saving)
        #expect(EditorSaveState.saved == EditorSaveState.saved)
        #expect(EditorSaveState.conflict("error") == EditorSaveState.conflict("error"))
        #expect(EditorSaveState.error("error") == EditorSaveState.error("error"))
    }

    @Test
    func stateInequality() {
        #expect(EditorSaveState.idle != EditorSaveState.editing)
        #expect(EditorSaveState.conflict("a") != EditorSaveState.conflict("b"))
        #expect(EditorSaveState.error("a") != EditorSaveState.error("b"))
    }
}

@MainActor
@Suite("EditorSaveStateController Tests")
struct EditorSaveStateControllerTests {

    @Test
    func applySaveSuccessCallsAllCallbacks() {
        let controller = EditorSaveStateController()
        var markPersistedTextCalled = false
        var clearConflictCalled = false
        var syncSessionCalled = false
        var scheduleSuccessClearCalled = false
        var notifyDidSaveCalled = false
        var hasUnsavedChangesSet = false
        var saveStateSet: EditorSaveState?

        controller.applySaveSuccess(
            content: "test content",
            markPersistedText: { _ in markPersistedTextCalled = true },
            clearConflict: { clearConflictCalled = true },
            syncSession: { syncSessionCalled = true },
            scheduleSuccessClear: { scheduleSuccessClearCalled = true },
            notifyDidSave: { _ in notifyDidSaveCalled = true },
            setHasUnsavedChanges: { hasUnsavedChangesSet = $0 },
            setSaveState: { saveStateSet = $0 }
        )

        #expect(markPersistedTextCalled)
        #expect(clearConflictCalled)
        #expect(syncSessionCalled)
        #expect(scheduleSuccessClearCalled)
        #expect(notifyDidSaveCalled)
        #expect(hasUnsavedChangesSet == false)
        #expect(saveStateSet == .saved)
    }

    @Test
    func applySaveFailureSetsErrorState() {
        let controller = EditorSaveStateController()
        var syncSessionCalled = false
        var scheduleSuccessClearCalled = false
        var saveStateSet: EditorSaveState?

        let error = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])

        controller.applySaveFailure(
            error: error,
            syncSession: { syncSessionCalled = true },
            scheduleSuccessClear: { scheduleSuccessClearCalled = true },
            setSaveState: { saveStateSet = $0 }
        )

        #expect(syncSessionCalled)
        #expect(scheduleSuccessClearCalled)
        if case .error(let message) = saveStateSet {
            #expect(message.contains("Save failed"))
        } else {
            Issue.record("Expected error state")
        }
    }

    @Test
    func applyMissingFileFailureSetsErrorState() {
        let controller = EditorSaveStateController()
        var scheduleSuccessClearCalled = false
        var saveStateSet: EditorSaveState?

        controller.applyMissingFileFailure(
            scheduleSuccessClear: { scheduleSuccessClearCalled = true },
            setSaveState: { saveStateSet = $0 }
        )

        #expect(scheduleSuccessClearCalled)
        if case .error(let message) = saveStateSet {
            #expect(message.contains("no longer exists on disk"))
        } else {
            Issue.record("Expected error state")
        }
    }
}