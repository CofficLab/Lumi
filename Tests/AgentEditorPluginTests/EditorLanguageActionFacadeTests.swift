#if canImport(XCTest)
import XCTest
@testable import Lumi

@MainActor
final class EditorLanguageActionFacadeTests: XCTestCase {
    func testFacadeInstantiates() {
        let facade = EditorLanguageActionFacade()
        XCTAssertNotNil(facade)
    }
}
#endif
