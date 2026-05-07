import Foundation
import Testing
@testable import DatabaseKit

struct DatabaseKitTests {
    @Test
    func databaseErrorFormatsReadableDescriptions() {
        #expect(DatabaseError.connectionFailed("timeout").errorDescription == "Connection failed: timeout")
        #expect(DatabaseError.driverNotFound(.redis).errorDescription == "Driver not found for type: Redis")
    }

    @Test
    func databaseValueDescriptionMatchesUnderlyingValue() {
        #expect(DatabaseValue.integer(7).description == "7")
        #expect(DatabaseValue.bool(true).description == "true")
        #expect(DatabaseValue.null.description == "NULL")
    }

    @Test
    func databaseConfigCodableRoundTripPreservesFields() throws {
        let config = DatabaseConfig(
            name: "Local DB",
            type: .sqlite,
            database: "/tmp/test.sqlite",
            options: ["mode": "ro"]
        )

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(DatabaseConfig.self, from: data)

        #expect(decoded.name == config.name)
        #expect(decoded.type == config.type)
        #expect(decoded.database == config.database)
        #expect(decoded.options == config.options)
    }

    @Test
    func databaseManagerCanRegisterAndUseMockDriver() async throws {
        let manager = DatabaseManager()
        let recorder = MockDriverRecorder()
        let driver = MockDatabaseDriver(type: .sqlite, recorder: recorder)
        await manager.register(driver: driver)

        let config = DatabaseConfig(name: "Mock", type: .sqlite, database: "mock.sqlite")
        let connection = try await manager.connect(config: config)

        #expect(connection is MockDatabaseConnection)
        #expect(await recorder.connectCallCount == 1)
        #expect(await recorder.connectedDatabases.contains("mock.sqlite"))
        #expect(await manager.getConnection(for: config.id) != nil)
    }

    @Test
    func databaseManagerProbeUsesTemporaryConnection() async throws {
        let manager = DatabaseManager()
        let recorder = MockDriverRecorder()
        let driver = MockDatabaseDriver(type: .sqlite, recorder: recorder)
        await manager.register(driver: driver)

        let config = DatabaseConfig(name: "Probe", type: .sqlite, database: "probe.sqlite")
        try await manager.probe(config: config)

        #expect(await recorder.connectCallCount == 1)
        #expect(await recorder.closeCallCount == 1)
        #expect(await manager.getConnection(for: config.id) == nil)
    }

    @Test
    func databaseManagerCachesPoolPerConfig() async throws {
        let manager = DatabaseManager()
        let recorder = MockDriverRecorder()
        let driver = MockDatabaseDriver(type: .sqlite, recorder: recorder)
        await manager.register(driver: driver)

        let config = DatabaseConfig(name: "Pool", type: .sqlite, database: "pool.sqlite")
        let first = try await manager.getPool(for: config)
        let second = try await manager.getPool(for: config)

        #expect(first === second)
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

    func connect(config: DatabaseConfig) async throws -> any DatabaseConnection {
        await recorder.recordConnect(database: config.database)
        return MockDatabaseConnection(recorder: recorder)
    }
}

private actor MockDatabaseConnection: DatabaseConnection {
    let recorder: MockDriverRecorder

    init(recorder: MockDriverRecorder) {
        self.recorder = recorder
    }

    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int { 0 }

    func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult {
        QueryResult(columns: [], rows: [], rowsAffected: 0)
    }

    func beginTransaction() async throws -> any DatabaseTransaction {
        MockDatabaseTransaction()
    }

    func close() async {
        await recorder.recordClose()
    }

    func isAlive() async -> Bool { true }
}

private actor MockDatabaseTransaction: DatabaseTransaction {
    func commit() async throws {}
    func rollback() async throws {}
    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int { 0 }
}
