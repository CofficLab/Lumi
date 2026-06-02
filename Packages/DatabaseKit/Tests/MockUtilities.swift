import Foundation
@testable import DatabaseKit

/// Recorder to track MockDatabaseDriver method calls
actor MockDriverRecorder {
    var connectCallCount = 0
    var closeCallCount = 0
    var executeCallCount = 0
    var queryCallCount = 0
    var connectedDatabases: [String] = []
    var executedSQL: [String] = []
    var queriedSQL: [String] = []

    func recordConnect(database: String) {
        connectCallCount += 1
        connectedDatabases.append(database)
    }

    func recordClose() {
        closeCallCount += 1
    }

    func recordExecute(sql: String) {
        executeCallCount += 1
        executedSQL.append(sql)
    }

    func recordQuery(sql: String) {
        queryCallCount += 1
        queriedSQL.append(sql)
    }

    func reset() {
        connectCallCount = 0
        closeCallCount = 0
        executeCallCount = 0
        queryCallCount = 0
        connectedDatabases.removeAll()
        executedSQL.removeAll()
        queriedSQL.removeAll()
    }
}

/// Mock implementation of DatabaseDriver
struct MockDatabaseDriver: DatabaseDriver {
    let type: DatabaseType
    let recorder: MockDriverRecorder

    init(type: DatabaseType, recorder: MockDriverRecorder) {
        self.type = type
        self.recorder = recorder
    }

    func connect(config: DatabaseConfig) async throws -> any DatabaseConnection {
        await recorder.recordConnect(database: config.database)
        return MockDatabaseConnection(recorder: recorder)
    }
}

/// Mock implementation of DatabaseConnection
actor MockDatabaseConnection: DatabaseConnection {
    let recorder: MockDriverRecorder
    var mockExecuteResult: Int = 0
    var mockQueryResult: QueryResult = QueryResult(columns: [], rows: [], rowsAffected: 0)
    var mockIsAlive: Bool = true

    init(recorder: MockDriverRecorder) {
        self.recorder = recorder
    }

    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        await recorder.recordExecute(sql: sql)
        return mockExecuteResult
    }

    func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult {
        await recorder.recordQuery(sql: sql)
        return mockQueryResult
    }

    func beginTransaction() async throws -> any DatabaseTransaction {
        MockDatabaseTransaction()
    }

    func close() async {
        await recorder.recordClose()
        mockIsAlive = false
    }

    func isAlive() async -> Bool {
        mockIsAlive
    }

    func setIsAlive(_ isAlive: Bool) {
        mockIsAlive = isAlive
    }
}

/// Mock implementation of DatabaseTransaction
actor MockDatabaseTransaction: DatabaseTransaction {
    var commitCallCount = 0
    var rollbackCallCount = 0
    var executeCallCount = 0
    var isCompleted = false

    func commit() async throws {
        guard !isCompleted else {
            throw DatabaseError.transactionFailed("Transaction already completed")
        }
        commitCallCount += 1
        isCompleted = true
    }

    func rollback() async throws {
        guard !isCompleted else {
            throw DatabaseError.transactionFailed("Transaction already completed")
        }
        rollbackCallCount += 1
        isCompleted = true
    }

    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        guard !isCompleted else {
            throw DatabaseError.transactionFailed("Transaction already completed")
        }
        executeCallCount += 1
        return 0
    }
}

enum DatabaseKitIntegrationConfig {
    private static let env = ProcessInfo.processInfo.environment

    static var mysql: DatabaseConfig? {
        guard let host = env["DATABASEKIT_MYSQL_HOST"],
              let database = env["DATABASEKIT_MYSQL_DATABASE"],
              let username = env["DATABASEKIT_MYSQL_USERNAME"] else {
            return nil
        }

        return DatabaseConfig(
            name: "MySQL Integration",
            type: .mysql,
            host: host,
            port: intEnv("DATABASEKIT_MYSQL_PORT") ?? 3306,
            database: database,
            username: username,
            password: env["DATABASEKIT_MYSQL_PASSWORD"]
        )
    }

    static var postgresql: DatabaseConfig? {
        guard let host = env["DATABASEKIT_POSTGRES_HOST"],
              let database = env["DATABASEKIT_POSTGRES_DATABASE"],
              let username = env["DATABASEKIT_POSTGRES_USERNAME"] else {
            return nil
        }

        return DatabaseConfig(
            name: "PostgreSQL Integration",
            type: .postgresql,
            host: host,
            port: intEnv("DATABASEKIT_POSTGRES_PORT") ?? 5432,
            database: database,
            username: username,
            password: env["DATABASEKIT_POSTGRES_PASSWORD"]
        )
    }

    static var redis: DatabaseConfig? {
        guard let host = env["DATABASEKIT_REDIS_HOST"] else {
            return nil
        }

        return DatabaseConfig(
            name: "Redis Integration",
            type: .redis,
            host: host,
            port: intEnv("DATABASEKIT_REDIS_PORT") ?? 6379,
            database: "redis",
            password: env["DATABASEKIT_REDIS_PASSWORD"]
        )
    }

    private static func intEnv(_ key: String) -> Int? {
        env[key].flatMap(Int.init)
    }
}
