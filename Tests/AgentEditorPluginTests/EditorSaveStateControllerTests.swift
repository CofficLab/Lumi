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
}
#endif
