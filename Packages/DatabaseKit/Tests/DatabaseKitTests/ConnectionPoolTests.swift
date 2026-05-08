import Foundation
import Testing
@testable import DatabaseKit

struct ConnectionPoolTests {
    @Test
    func connectionPoolInitializesWithConfigAndDriver() async throws {
        let recorder = MockDriverRecorder()
        let driver = MockDatabaseDriver(type: .sqlite, recorder: recorder)
        let config = DatabaseConfig(name: "Pool Test", type: .sqlite, database: "pool.sqlite")

        let pool = ConnectionPool(config: config, driver: driver, maxConnections: 3)

        #expect(pool.maxConnections == 3)
    }

    @Test
    func connectionPoolAcquiresNewConnection() async throws {
        let recorder = MockDriverRecorder()
        let driver = MockDatabaseDriver(type: .sqlite, recorder: recorder)
        let config = DatabaseConfig(name: "Acquire Test", type: .sqlite, database: "acquire.sqlite")

        let pool = ConnectionPool(config: config, driver: driver)

        let connection = try await pool.acquire()
        #expect(connection is MockDatabaseConnection)
        #expect(await recorder.connectCallCount == 1)
        #expect(await recorder.connectedDatabases.contains("acquire.sqlite"))
    }

    @Test
    func connectionPoolReleasesConnection() async throws {
        let recorder = MockDriverRecorder()
        let driver = MockDatabaseDriver(type: .sqlite, recorder: recorder)
        let config = DatabaseConfig(name: "Release Test", type: .sqlite, database: "release.sqlite")

        let pool = ConnectionPool(config: config, driver: driver)
        let connection = try await pool.acquire()

        await pool.release(connection)
        #expect(await recorder.closeCallCount == 1)
    }

    @Test
    func connectionPoolShutdownClosesAllConnections() async throws {
        let recorder = MockDriverRecorder()
        let driver = MockDatabaseDriver(type: .sqlite, recorder: recorder)
        let config = DatabaseConfig(name: "Shutdown Test", type: .sqlite, database: "shutdown.sqlite")

        let pool = ConnectionPool(config: config, driver: driver)

        // Acquire multiple connections
        let conn1 = try await pool.acquire()
        let conn2 = try await pool.acquire()
        let conn3 = try await pool.acquire()

        await pool.shutdown()
        #expect(await recorder.closeCallCount == 3)
    }

    @Test
    func connectionPoolMaxConnectionsLimit() async throws {
        let recorder = MockDriverRecorder()
        let driver = MockDatabaseDriver(type: .sqlite, recorder: recorder)
        let config = DatabaseConfig(name: "Limit Test", type: .sqlite, database: "limit.sqlite")

        let pool = ConnectionPool(config: config, driver: driver, maxConnections: 2)

        #expect(pool.maxConnections == 2)
    }

    @Test
    func connectionPoolCanBeUsedMultipleTimes() async throws {
        let recorder = MockDriverRecorder()
        let driver = MockDatabaseDriver(type: .sqlite, recorder: recorder)
        let config = DatabaseConfig(name: "Reuse Test", type: .sqlite, database: "reuse.sqlite")

        let pool = ConnectionPool(config: config, driver: driver)

        // First acquire-release cycle
        let conn1 = try await pool.acquire()
        await pool.release(conn1)

        // Second acquire-release cycle
        let conn2 = try await pool.acquire()
        await pool.release(conn2)

        #expect(await recorder.connectCallCount == 2)
        #expect(await recorder.closeCallCount == 2)
    }
}