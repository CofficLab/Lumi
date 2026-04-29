#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorStatusToastControllerTests: XCTestCase {
    func testControllerInstantiates() {
        let controller = EditorStatusToastController()
        XCTAssertNotNil(controller)
    }
}
#endif
