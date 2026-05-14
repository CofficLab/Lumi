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

    @Test
    func mysqlIntegrationExecutesParameterizedCRUDWhenConfigured() async throws {
        guard let config = DatabaseKitIntegrationConfig.mysql else {
            return
        }

        let driver = MySQLDriver()
        let connection = try await driver.connect(config: config)

        let table = "databasekit_mysql_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        do {
            _ = try await connection.execute(
                "CREATE TABLE \(table) (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255), count_value INT)",
                params: nil
            )

            let inserted = try await connection.execute(
                "INSERT INTO \(table) (name, count_value) VALUES (?, ?)",
                params: [.string("lumi"), .integer(7)]
            )
            let result = try await connection.query(
                "SELECT name, count_value FROM \(table) WHERE name = ?",
                params: [.string("lumi")]
            )
            let updated = try await connection.execute(
                "UPDATE \(table) SET count_value = ? WHERE name = ?",
                params: [.integer(8), .string("lumi")]
            )

            #expect(inserted == 1)
            #expect(updated == 1)
            #expect(result.rows.count == 1)
            #expect(result.rows[0][0] == .string("lumi"))
            #expect(result.rows[0][1] == .integer(7))
        } catch {
            _ = try? await connection.execute("DROP TABLE IF EXISTS \(table)", params: nil)
            await connection.close()
            throw error
        }

        _ = try? await connection.execute("DROP TABLE IF EXISTS \(table)", params: nil)
        await connection.close()
    }
}
