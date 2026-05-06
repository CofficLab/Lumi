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

    func testDatabaseConfigCodableRoundTripPreservesFields() throws {
        let config = DatabaseConfig(
            name: "Local DB",
            type: .sqlite,
            host: nil,
            port: nil,
            database: "/tmp/test.sqlite",
            username: nil,
            password: nil,
            options: ["mode": "ro"]
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(DatabaseConfig.self, from: data)

        XCTAssertEqual(decoded.name, config.name)
        XCTAssertEqual(decoded.type, config.type)
        XCTAssertEqual(decoded.database, config.database)
        XCTAssertEqual(decoded.options, config.options)
    }

    func testDatabaseManagerCanRegisterAndUseMockDriver() async throws {
        let manager = DatabaseManager()
        let recorder = MockDriverRecorder()
        let driver = MockDatabaseDriver(type: .sqlite, recorder: recorder)
        await manager.register(driver: driver)

        let config = DatabaseConfig(
            name: "Mock",
            type: .sqlite,
            host: nil,
            port: nil,
            database: "mock.sqlite",
            username: nil,
            password: nil,
            options: nil
        )

        let connection = try await manager.connect(config: config)
        let connectCallCount = await recorder.connectCallCount
        let connectedDatabases = await recorder.connectedDatabases
        let storedConnection = await manager.getConnection(for: config.id)

        XCTAssertTrue(connection is MockDatabaseConnection)
        XCTAssertEqual(connectCallCount, 1)
        XCTAssertTrue(connectedDatabases.contains("mock.sqlite"))
        XCTAssertNotNil(storedConnection)
    }

    func testDatabaseManagerProbeUsesTemporaryConnection() async throws {
        let manager = DatabaseManager()
        let recorder = MockDriverRecorder()
        let driver = MockDatabaseDriver(type: .sqlite, recorder: recorder)
        await manager.register(driver: driver)

        let config = DatabaseConfig(
            name: "Probe",
            type: .sqlite,
            host: nil,
            port: nil,
            database: "probe.sqlite",
            username: nil,
            password: nil,
            options: nil
        )

        try await manager.probe(config: config)
        let connectCallCount = await recorder.connectCallCount
        let closeCallCount = await recorder.closeCallCount
        let storedConnection = await manager.getConnection(for: config.id)

        XCTAssertEqual(connectCallCount, 1)
        XCTAssertEqual(closeCallCount, 1)
        XCTAssertNil(storedConnection)
    }

    func testDatabaseManagerCachesPoolPerConfig() async throws {
        let manager = DatabaseManager()
        let recorder = MockDriverRecorder()
        let driver = MockDatabaseDriver(type: .sqlite, recorder: recorder)
        await manager.register(driver: driver)

        let config = DatabaseConfig(
            name: "Pool",
            type: .sqlite,
            host: nil,
            port: nil,
            database: "pool.sqlite",
            username: nil,
            password: nil,
            options: nil
        )

        let first = try await manager.getPool(for: config)
        let second = try await manager.getPool(for: config)

        XCTAssertTrue(first === second)
    }
}

private actor MockDriverRecorder {
    var connectCallCount = 0
    var closeCallCount = 0
    var connectedDatabases: [String] = []

    func recordConnect(database: String) {
        connectCallCount += 1
        connectedDatabases.append(database)
    }

    func recordClose() {
        closeCallCount += 1
    }
}

private struct MockDatabaseDriver: DatabaseDriver {
    let type: DatabaseType
    let recorder: MockDriverRecorder

    func connect(config: DatabaseConfig) async throws -> DatabaseConnection {
        await recorder.recordConnect(database: config.database)
        return MockDatabaseConnection(recorder: recorder)
    }
}

private actor MockDatabaseConnection: DatabaseConnection {
    let recorder: MockDriverRecorder

    init(recorder: MockDriverRecorder) {
        self.recorder = recorder
    }

    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        0
    }

    func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult {
        QueryResult(columns: [], rows: [], rowsAffected: 0)
    }

    func beginTransaction() async throws -> DatabaseTransaction {
        MockDatabaseTransaction()
    }

    func close() async {
        await recorder.recordClose()
    }

    func isAlive() async -> Bool {
        true
    }
}

private actor MockDatabaseTransaction: DatabaseTransaction {
    func commit() async throws {}
    func rollback() async throws {}
    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int { 0 }
}
#endif
