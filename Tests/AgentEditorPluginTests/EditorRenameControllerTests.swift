#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorRenameControllerTests: XCTestCase {
    func testRenameMessagesAreStable() {
        let controller = EditorRenameController()

        XCTAssertFalse(controller.cancelledMessage().isEmpty)
        XCTAssertFalse(controller.inProgressMessage().isEmpty)
        XCTAssertFalse(controller.failedMessage().isEmpty)
        XCTAssertFalse(controller.notAppliedMessage().isEmpty)
        XCTAssertTrue(controller.completedMessage(changedFiles: 3).contains("3"))
    }
}
#endif
