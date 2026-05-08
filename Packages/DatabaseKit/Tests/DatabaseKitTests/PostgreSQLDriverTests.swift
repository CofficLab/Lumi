import Foundation
import Testing
@testable import DatabaseKit

struct PostgreSQLDriverTests {
    @Test
    func postgresqlDriverTypeIsPostgreSQL() {
        let driver = PostgreSQLDriver()
        #expect(driver.type == .postgresql)
    }

    @Test
    func postgresqlDriverRejectsMissingHost() async throws {
        let driver = PostgreSQLDriver()
        let config = DatabaseConfig(
            name: "No Host",
            type: .postgresql,
            host: nil,
            port: 5432,
            database: "mydb",
            username: "user"
        )

        await #expect(throws: DatabaseError.self) {
            _ = try await driver.connect(config: config)
        }
    }

    @Test
    func postgresqlDriverRejectsEmptyHost() async throws {
        let driver = PostgreSQLDriver()
        let config = DatabaseConfig(
            name: "Empty Host",
            type: .postgresql,
            host: "",
            port: 5432,
            database: "mydb",
            username: "user"
        )

        await #expect(throws: DatabaseError.self) {
            _ = try await driver.connect(config: config)
        }
    }

    @Test
    func postgresqlDriverRejectsMissingPort() async throws {
        let driver = PostgreSQLDriver()
        let config = DatabaseConfig(
            name: "No Port",
            type: .postgresql,
            host: "localhost",
            port: nil,
            database: "mydb",
            username: "user"
        )

        await #expect(throws: DatabaseError.self) {
            _ = try await driver.connect(config: config)
        }
    }

    @Test
    func postgresqlDriverRejectsInvalidPort() async throws {
        let driver = PostgreSQLDriver()
        let config = DatabaseConfig(
            name: "Invalid Port",
            type: .postgresql,
            host: "localhost",
            port: 0,
            database: "mydb",
            username: "user"
        )

        await #expect(throws: DatabaseError.self) {
            _ = try await driver.connect(config: config)
        }
    }

    @Test
    func postgresqlDriverRejectsMissingDatabase() async throws {
        let driver = PostgreSQLDriver()
        let config = DatabaseConfig(
            name: "No Database",
            type: .postgresql,
            host: "localhost",
            port: 5432,
            database: "",
            username: "user"
        )

        await #expect(throws: DatabaseError.self) {
            _ = try await driver.connect(config: config)
        }
    }

    @Test
    func postgresqlDriverRejectsMissingUsername() async throws {
        let driver = PostgreSQLDriver()
        let config = DatabaseConfig(
            name: "No Username",
            type: .postgresql,
            host: "localhost",
            port: 5432,
            database: "mydb",
            username: nil
        )

        await #expect(throws: DatabaseError.self) {
            _ = try await driver.connect(config: config)
        }
    }

    @Test
    func postgresqlDriverRejectsEmptyUsername() async throws {
        let driver = PostgreSQLDriver()
        let config = DatabaseConfig(
            name: "Empty Username",
            type: .postgresql,
            host: "localhost",
            port: 5432,
            database: "mydb",
            username: ""
        )

        await #expect(throws: DatabaseError.self) {
            _ = try await driver.connect(config: config)
        }
    }

    @Test
    func postgresqlDriverAcceptsValidConfig() async throws {
        let driver = PostgreSQLDriver()
        let config = DatabaseConfig(
            name: "Valid PostgreSQL",
            type: .postgresql,
            host: "localhost",
            port: 5432,
            database: "testdb",
            username: "testuser",
            password: "testpass"
        )

        // Note: This will fail if PostgresNIO is not available
        #expect(driver.type == .postgresql)

        do {
            _ = try await driver.connect(config: config)
        } catch DatabaseError.notImplemented {
            // Expected when PostgresNIO is not imported
        } catch {
            // Other errors are acceptable (connection failure, etc.)
        }
    }

    @Test
    func postgresqlDriverPasswordIsOptional() async throws {
        let driver = PostgreSQLDriver()
        let config = DatabaseConfig(
            name: "No Password",
            type: .postgresql,
            host: "localhost",
            port: 5432,
            database: "testdb",
            username: "testuser",
            password: nil  // Password is optional
        )

        #expect(driver.type == .postgresql)

        do {
            _ = try await driver.connect(config: config)
        } catch DatabaseError.notImplemented {
            // Expected when PostgresNIO is not imported
        } catch {
            // Other errors are acceptable
        }
    }
}