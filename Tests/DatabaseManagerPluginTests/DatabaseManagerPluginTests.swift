#if canImport(XCTest)
import XCTest
@testable import Lumi

final class DatabaseManagerPluginTests: XCTestCase {

    func testPluginMetadataRemainsStable() {
        XCTAssertEqual(DatabaseManagerPlugin.id, "DatabaseManager")
        XCTAssertEqual(DatabaseManagerPlugin.navigationId, "database_manager")
        XCTAssertEqual(DatabaseManagerPlugin.iconName, "server.rack")
        XCTAssertFalse(DatabaseManagerPlugin.enable)
        XCTAssertEqual(DatabaseManagerPlugin.order, 50)
    }
}
#endif
