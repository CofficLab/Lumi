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
    func connectionPoolReleaseKeepsConnectionIdleForReuse() async throws {
        let recorder = MockDriverRecorder()
        let driver = MockDatabaseDriver(type: .sqlite, recorder: recorder)
        let config = DatabaseConfig(name: "Release Test", type: .sqlite, database: "release.sqlite")

        let pool = ConnectionPool(config: config, driver: driver)
        let connection = try await pool.acquire()

        await pool.release(connection)
        #expect(await recorder.closeCallCount == 0)

        let reusedConnection = try await pool.acquire()
        #expect(reusedConnection is MockDatabaseConnection)
        #expect(await recorder.connectCallCount == 1)

        await pool.release(reusedConnection)
        await pool.shutdown()
        #expect(await recorder.closeCallCount == 1)
    }

    @Test
    func connectionPoolShutdownClosesAllConnections() async throws {
        let recorder = MockDriverRecorder()
        let driver = MockDatabaseDriver(type: .sqlite, recorder: recorder)
        let config = DatabaseConfig(name: "Shutdown Test", type: .sqlite, database: "shutdown.sqlite")

        let pool = ConnectionPool(config: config, driver: driver)

        let conn1 = try await pool.acquire()
        let conn2 = try await pool.acquire()
        let conn3 = try await pool.acquire()

        await pool.release(conn1)
        await pool.release(conn2)
        await pool.release(conn3)

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
    func connectionPoolNormalizesInvalidMaxConnectionsToOne() async throws {
        let recorder = MockDriverRecorder()
        let driver = MockDatabaseDriver(type: .sqlite, recorder: recorder)
        let config = DatabaseConfig(name: "Invalid Limit Test", type: .sqlite, database: "invalid-limit.sqlite")

        let pool = ConnectionPool(config: config, driver: driver, maxConnections: 0)

        #expect(pool.maxConnections == 1)

        let connection = try await pool.acquire()
        #expect(connection is MockDatabaseConnection)
        #expect(await recorder.connectCallCount == 1)

        await pool.release(connection)
        await pool.shutdown()
    }

    @Test
    func connectionPoolWaitsWhenMaxConnectionsAreInUse() async throws {
        let recorder = MockDriverRecorder()
        let driver = MockDatabaseDriver(type: .sqlite, recorder: recorder)
        let config = DatabaseConfig(name: "Backpressure Test", type: .sqlite, database: "backpressure.sqlite")
        let pool = ConnectionPool(config: config, driver: driver, maxConnections: 2)

        let conn1 = try await pool.acquire()
        let conn2 = try await pool.acquire()

        async let waitingConnection = pool.acquire()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(await recorder.connectCallCount == 2)

        await pool.release(conn1)
        let conn3 = try await waitingConnection

        #expect(conn3 is MockDatabaseConnection)
        #expect(await recorder.connectCallCount == 2)

        await pool.release(conn2)
        await pool.release(conn3)
        await pool.shutdown()
    }

    @Test
    func connectionPoolDiscardsDeadConnectionsOnRelease() async throws {
        let recorder = MockDriverRecorder()
        let driver = MockDatabaseDriver(type: .sqlite, recorder: recorder)
        let config = DatabaseConfig(name: "Dead Connection Test", type: .sqlite, database: "dead.sqlite")
        let pool = ConnectionPool(config: config, driver: driver, maxConnections: 1)

        let connection = try await pool.acquire()
        let mockConnection = try #require(connection as? MockDatabaseConnection)
        await mockConnection.setIsAlive(false)

        await pool.release(connection)
        #expect(await recorder.closeCallCount == 1)

        let replacement = try await pool.acquire()
        #expect(replacement is MockDatabaseConnection)
        #expect(await recorder.connectCallCount == 2)

        await pool.release(replacement)
        await pool.shutdown()
    }

    @Test
    func connectionPoolIgnoresDuplicateRelease() async throws {
        let recorder = MockDriverRecorder()
        let driver = MockDatabaseDriver(type: .sqlite, recorder: recorder)
        let config = DatabaseConfig(name: "Duplicate Release Test", type: .sqlite, database: "duplicate-release.sqlite")
        let pool = ConnectionPool(config: config, driver: driver, maxConnections: 2)

        let connection = try await pool.acquire()
        await pool.release(connection)
        await pool.release(connection)

        let first = try await pool.acquire()
        let second = try await pool.acquire()

        #expect(first is MockDatabaseConnection)
        #expect(second is MockDatabaseConnection)
        #expect(await recorder.connectCallCount == 2)

        await pool.release(first)
        await pool.release(second)
        await pool.shutdown()
        #expect(await recorder.closeCallCount == 2)
    }

    @Test
    func connectionPoolClosesForeignConnectionOnRelease() async throws {
        let recorder = MockDriverRecorder()
        let driver = MockDatabaseDriver(type: .sqlite, recorder: recorder)
        let poolConfig = DatabaseConfig(name: "Pool", type: .sqlite, database: "pool.sqlite")
        let foreignConfig = DatabaseConfig(name: "Foreign", type: .sqlite, database: "foreign.sqlite")
        let pool = ConnectionPool(config: poolConfig, driver: driver)

        let foreignConnection = try await driver.connect(config: foreignConfig)
        await pool.release(foreignConnection)

        #expect(await recorder.closeCallCount == 1)
        #expect(await recorder.connectCallCount == 1)

        await pool.shutdown()
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

        #expect(await recorder.connectCallCount == 1)
        #expect(await recorder.closeCallCount == 0)

        await pool.shutdown()
        #expect(await recorder.closeCallCount == 1)
    }
}
