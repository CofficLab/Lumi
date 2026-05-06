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

    func testDatabaseErrorFormatsReadableDescriptions() {
        XCTAssertEqual(
            DatabaseError.connectionFailed("timeout").errorDescription,
            "Connection failed: timeout"
        )
        XCTAssertEqual(
            DatabaseError.driverNotFound(.redis).errorDescription,
            "Driver not found for type: Redis"
        )
    }

    func testDatabaseValueDescriptionMatchesUnderlyingValue() {
        XCTAssertEqual(DatabaseValue.integer(7).description, "7")
        XCTAssertEqual(DatabaseValue.bool(true).description, "true")
        XCTAssertEqual(DatabaseValue.null.description, "NULL")
    }
}
#endif
