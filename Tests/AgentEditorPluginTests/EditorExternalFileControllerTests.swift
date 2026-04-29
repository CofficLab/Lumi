#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorExternalFileControllerTests: XCTestCase {
    func testRegisterConflictDeduplicatesSamePayload() {
        let controller = EditorExternalFileController()
        let date = Date()

        XCTAssertTrue(controller.registerConflictIfNeeded(content: "disk v2", modificationDate: date))
        XCTAssertFalse(controller.registerConflictIfNeeded(content: "disk v2", modificationDate: date))
    }

    func testKeepEditorVersionRecordsConflictModificationDate() {
        let controller = EditorExternalFileController()
        let date = Date()
        var cleared = false
        var saveStateIsEditing: Bool?
        var didSync = false

        _ = controller.registerConflictIfNeeded(content: "disk v2", modificationDate: date)
        controller.keepEditorVersionForConflict(
            hasUnsavedChanges: true,
            clearConflict: {
                cleared = true
            },
            setSaveState: { isEditing in
                saveStateIsEditing = isEditing
            },
            syncSession: {
                didSync = true
            }
        )

        XCTAssertTrue(cleared)
        XCTAssertEqual(saveStateIsEditing, true)
        XCTAssertTrue(didSync)
        XCTAssertNil(controller.conflictState)
    }
}
#endif
