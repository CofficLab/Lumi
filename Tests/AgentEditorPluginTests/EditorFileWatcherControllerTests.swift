#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorFileWatcherControllerTests: XCTestCase {
    func testControllerInstantiates() {
        let controller = EditorFileWatcherController()
        XCTAssertNotNil(controller)
    }
}
#endif
