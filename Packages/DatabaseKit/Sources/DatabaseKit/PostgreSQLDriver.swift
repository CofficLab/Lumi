import Foundation

#if canImport(PostgresNIO)
import Logging
import NIOCore
import NIOPosix
import PostgresNIO

public final class PostgreSQLDriver: DatabaseDriver, Sendable {
    public var type: DatabaseType { .postgresql }

    public init() {}

    public func connect(config: DatabaseConfig) async throws -> any DatabaseConnection {
        guard let host = config.host, !host.isEmpty else {
            throw DatabaseError.invalidConfiguration("PostgreSQL 需要有效的主机地址")
        }
        guard let port = config.port, port > 0 else {
            throw DatabaseError.invalidConfiguration("PostgreSQL 需要有效的端口")
        }
        guard !config.database.isEmpty else {
            throw DatabaseError.invalidConfiguration("PostgreSQL 需要指定数据库名")
        }
        guard let user = config.username, !user.isEmpty else {
            throw DatabaseError.invalidConfiguration("PostgreSQL 需要用户名")
        }

        return try await PGConnection(
            host: host,
            port: port,
            username: user,
            password: config.password,
            database: config.database
        )
    }
}

public actor PGConnection: DatabaseConnection {
    private let group: EventLoopGroup
    private let conn: PostgresConnection
    private let logger = Logger(label: "com.lumi.postgres")

    public init(host: String, port: Int, username: String, password: String?, database: String) async throws {
        group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        let config = PostgresConnection.Configuration(
            host: host,
            port: port,
            username: username,
            password: password ?? "",
            database: database,
            tls: .disable
        )

        conn = try await PostgresConnection.connect(
            on: group.next(),
            configuration: config,
            id: 1,
            logger: logger
        ).get()
    }

    public func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        let result = try await conn.query(sql, toPostgresData(params ?? [])).get()
        return result.metadata.rows ?? result.rows.count
    }

    public func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult {
        let rowSequence = try await conn.query(
            PostgresQuery(unsafeSQL: sql, binds: toPostgresBindings(params ?? [])),
            logger: Logger(label: "com.lumi.postgres.query")
        )

        var columns: [String] = []
        var resultRows: [[DatabaseValue]] = []

        for try await row in rowSequence {
            var values: [DatabaseValue] = []
            for cell in row {
                if resultRows.isEmpty {
                    columns.append(cell.columnName)
                }
                if let s = try? cell.decode(String.self) {
                    values.append(.string(s))
                } else if let i = try? cell.decode(Int.self) {
                    values.append(.integer(i))
                } else if let d = try? cell.decode(Double.self) {
                    values.append(.double(d))
                } else if let b = try? cell.decode(Bool.self) {
                    values.append(.bool(b))
                } else if var bytes = cell.bytes {
                    if let readBytes = bytes.readBytes(length: bytes.readableBytes) {
                        values.append(.data(Data(readBytes)))
                    } else {
                        values.append(.null)
                    }
                } else {
                    values.append(.null)
                }
            }
            resultRows.append(values)
        }

        return QueryResult(columns: columns, rows: resultRows, rowsAffected: resultRows.count)
    }

    public func beginTransaction() async throws -> any DatabaseTransaction {
        let query = PostgresQuery(unsafeSQL: "BEGIN")
        _ = try await conn.query(query, logger: Logger(label: "com.lumi.postgres.transaction")).get()
        return PGTransaction(connection: self)
    }

    public func close() async {
        try? await conn.close()
        try? await group.shutdownGracefully()
    }

    public func isAlive() async -> Bool {
        !conn.isClosed
    }

    private func toPostgresData(_ params: [DatabaseValue]) -> [PostgresData] {
        params.map { value in
            switch value {
            case .integer(let int): return PostgresData(int: int)
            case .double(let double): return PostgresData(double: double)
            case .string(let string): return PostgresData(string: string)
            case .bool(let bool): return PostgresData(bool: bool)
            case .data(let data): return PostgresData(bytes: data)
            case .null: return .null
            }
        }
    }

    private func toPostgresBindings(_ params: [DatabaseValue]) -> PostgresBindings {
        var bindings = PostgresBindings(capacity: params.count)
        toPostgresData(params).forEach { bindings.append($0) }
        return bindings
    }
}

public final actor PGTransaction: DatabaseTransaction {
    private let connection: PGConnection
    private var completed = false

    init(connection: PGConnection) {
        self.connection = connection
    }

    public func commit() async throws {
        guard !completed else { throw DatabaseError.transactionFailed("Transaction already completed") }
        _ = try await connection.execute("COMMIT", params: nil)
        completed = true
    }

    public func rollback() async throws {
        guard !completed else { throw DatabaseError.transactionFailed("Transaction already completed") }
        _ = try await connection.execute("ROLLBACK", params: nil)
        completed = true
    }

    public func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        guard !completed else { throw DatabaseError.transactionFailed("Transaction already completed") }
        return try await connection.execute(sql, params: params)
    }
}
#else
public final class PostgreSQLDriver: DatabaseDriver, Sendable {
    public var type: DatabaseType { .postgresql }

    public init() {}

    public func connect(config: DatabaseConfig) async throws -> any DatabaseConnection {
        throw DatabaseError.notImplemented
    }
}
#endif
