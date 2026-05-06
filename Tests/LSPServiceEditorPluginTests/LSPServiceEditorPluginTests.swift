#if canImport(XCTest)
import XCTest
@testable import Lumi

final class LSPServiceEditorPluginTests: XCTestCase {

    func testPluginMetadataRemainsStable() {
        XCTAssertEqual(LSPServiceEditorPlugin.id, "LSPServiceEditor")
        XCTAssertEqual(LSPServiceEditorPlugin.iconName, "server.rack")
        XCTAssertTrue(LSPServiceEditorPlugin.enable)
        XCTAssertEqual(LSPServiceEditorPlugin.order, 5)
        XCTAssertFalse(LSPServiceEditorPlugin.isConfigurable)
    }

    func testPluginAdvertisesEditorExtensions() {
        XCTAssertTrue(LSPServiceEditorPlugin.shared.providesEditorExtensions)
    }
}
#endif
