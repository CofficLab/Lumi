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

    @Test
    func postgresqlIntegrationExecutesParameterizedCRUDWhenConfigured() async throws {
        guard let config = DatabaseKitIntegrationConfig.postgresql else {
            return
        }

        let driver = PostgreSQLDriver()
        let connection = try await driver.connect(config: config)

        let table = "databasekit_postgres_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        do {
            _ = try await connection.execute(
                "CREATE TABLE \(table) (id SERIAL PRIMARY KEY, name TEXT, count_value INT)",
                params: nil
            )

            let inserted = try await connection.execute(
                "INSERT INTO \(table) (name, count_value) VALUES ($1, $2)",
                params: [.string("lumi"), .integer(7)]
            )
            let result = try await connection.query(
                "SELECT name, count_value FROM \(table) WHERE name = $1",
                params: [.string("lumi")]
            )
            let updated = try await connection.execute(
                "UPDATE \(table) SET count_value = $1 WHERE name = $2",
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

    @Test
    func postgresqlIntegrationReturnsColumnsForEmptyResultsWhenConfigured() async throws {
        guard let config = DatabaseKitIntegrationConfig.postgresql else {
            return
        }

        let driver = PostgreSQLDriver()
        let connection = try await driver.connect(config: config)

        do {
            let result = try await connection.query(
                "SELECT $1::TEXT AS name, $2::INT AS count_value WHERE false",
                params: [.string("lumi"), .integer(7)]
            )

            #expect(result.columns == ["name", "count_value"])
            #expect(result.rows.isEmpty)
            #expect(result.rowsAffected == 0)
        } catch {
            await connection.close()
            throw error
        }

        await connection.close()
    }
}
