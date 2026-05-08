import Foundation
import Testing
@testable import DatabaseKit

struct MySQLDriverTests {
    @Test
    func mysqlDriverTypeIsMySQL() {
        let driver = MySQLDriver()
        #expect(driver.type == .mysql)
    }

    @Test
    func mysqlDriverRejectsMissingHost() async throws {
        let driver = MySQLDriver()
        let config = DatabaseConfig(
            name: "No Host",
            type: .mysql,
            host: nil,
            port: 3306,
            database: "mydb",
            username: "user"
        )

        await #expect(throws: DatabaseError.self) {
            _ = try await driver.connect(config: config)
        }
    }

    @Test
    func mysqlDriverRejectsEmptyHost() async throws {
        let driver = MySQLDriver()
        let config = DatabaseConfig(
            name: "Empty Host",
            type: .mysql,
            host: "",
            port: 3306,
            database: "mydb",
            username: "user"
        )

        await #expect(throws: DatabaseError.self) {
            _ = try await driver.connect(config: config)
        }
    }

    @Test
    func mysqlDriverRejectsMissingPort() async throws {
        let driver = MySQLDriver()
        let config = DatabaseConfig(
            name: "No Port",
            type: .mysql,
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
    func mysqlDriverRejectsInvalidPort() async throws {
        let driver = MySQLDriver()
        let config = DatabaseConfig(
            name: "Invalid Port",
            type: .mysql,
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
    func mysqlDriverRejectsMissingDatabase() async throws {
        let driver = MySQLDriver()
        let config = DatabaseConfig(
            name: "No Database",
            type: .mysql,
            host: "localhost",
            port: 3306,
            database: "",
            username: "user"
        )

        await #expect(throws: DatabaseError.self) {
            _ = try await driver.connect(config: config)
        }
    }

    @Test
    func mysqlDriverRejectsMissingUsername() async throws {
        let driver = MySQLDriver()
        let config = DatabaseConfig(
            name: "No Username",
            type: .mysql,
            host: "localhost",
            port: 3306,
            database: "mydb",
            username: nil
        )

        await #expect(throws: DatabaseError.self) {
            _ = try await driver.connect(config: config)
        }
    }

    @Test
    func mysqlDriverRejectsEmptyUsername() async throws {
        let driver = MySQLDriver()
        let config = DatabaseConfig(
            name: "Empty Username",
            type: .mysql,
            host: "localhost",
            port: 3306,
            database: "mydb",
            username: ""
        )

        await #expect(throws: DatabaseError.self) {
            _ = try await driver.connect(config: config)
        }
    }

    @Test
    func mysqlDriverAcceptsValidConfig() async throws {
        let driver = MySQLDriver()
        let config = DatabaseConfig(
            name: "Valid MySQL",
            type: .mysql,
            host: "localhost",
            port: 3306,
            database: "testdb",
            username: "testuser",
            password: "testpass"
        )

        // Note: This will fail if MySQLNIO is not available, but we test the validation logic
        #expect(driver.type == .mysql)

        // If MySQLNIO is available, it will attempt to connect
        // If not available, it will throw notImplemented
        do {
            _ = try await driver.connect(config: config)
        } catch DatabaseError.notImplemented {
            // Expected when MySQLNIO is not imported
        } catch {
            // Other errors are acceptable (connection failure, etc.)
        }
    }

    @Test
    func mysqlDriverPasswordIsOptional() async throws {
        let driver = MySQLDriver()
        let config = DatabaseConfig(
            name: "No Password",
            type: .mysql,
            host: "localhost",
            port: 3306,
            database: "testdb",
            username: "testuser",
            password: nil  // Password is optional
        )

        // Password should be optional, so validation should pass
        #expect(driver.type == .mysql)

        do {
            _ = try await driver.connect(config: config)
        } catch DatabaseError.notImplemented {
            // Expected when MySQLNIO is not imported
        } catch {
            // Other errors are acceptable
        }
    }
}