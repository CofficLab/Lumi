import Foundation

#if canImport(MySQLNIO)
import Logging
import MySQLNIO
import NIOCore
import NIOPosix

public final class MySQLDriver: DatabaseDriver, Sendable {
    public var type: DatabaseType { .mysql }

    public init() {}

    public func connect(config: DatabaseConfig) async throws -> any DatabaseConnection {
        guard let host = config.host, !host.isEmpty else {
            throw DatabaseError.invalidConfiguration("MySQL 需要有效的主机地址")
        }
        guard let port = config.port, port > 0 else {
            throw DatabaseError.invalidConfiguration("MySQL 需要有效的端口")
        }
        guard !config.database.isEmpty else {
            throw DatabaseError.invalidConfiguration("MySQL 需要指定数据库名")
        }
        guard let user = config.username, !user.isEmpty else {
            throw DatabaseError.invalidConfiguration("MySQL 需要用户名")
        }

        return try await MySQLConnection(
            host: host,
            port: port,
            username: user,
            password: config.password,
            database: config.database
        )
    }
}

public actor MySQLConnection: DatabaseConnection {
    private let group: EventLoopGroup
    private var conn: MySQLNIO.MySQLConnection?

    public init(host: String, port: Int, username: String, password: String?, database: String) async throws {
        group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let socketAddress = try SocketAddress.makeAddressResolvingHost(host, port: port)
        let future = MySQLNIO.MySQLConnection.connect(
            to: socketAddress,
            username: username,
            database: database,
            password: password,
            tlsConfiguration: nil,
            serverHostname: nil,
            on: group.next()
        )
        conn = try await future.get()
    }

    public func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        guard let conn else { throw DatabaseError.connectionFailed("Not connected") }
        nonisolated(unsafe) var affectedRows = 0
        _ = try await conn.query(
            sql,
            toMySQLData(params ?? []),
            onMetadata: { metadata in
                affectedRows = Int(metadata.affectedRows)
            }
        ).get()
        return affectedRows
    }

    public func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult {
        guard let conn else { throw DatabaseError.connectionFailed("Not connected") }
        let rows = try await conn.query(sql, toMySQLData(params ?? [])).get()

        var resultRows: [[DatabaseValue]] = []
        var columns: [String] = []
        if let first = rows.first {
            columns = first.columnDefinitions.map(\.name)
        }

        for row in rows {
            var values: [DatabaseValue] = []
            for colDef in row.columnDefinitions {
                let data = row.column(colDef.name)
                if let data {
                    if let s = data.string { values.append(.string(s)) }
                    else if let i = data.int { values.append(.integer(i)) }
                    else if let f = data.double { values.append(.double(f)) }
                    else if let b = data.bool { values.append(.bool(b)) }
                    else if let buffer = data.buffer {
                        var buffer = buffer
                        if let bytes = buffer.readBytes(length: buffer.readableBytes) {
                            values.append(.data(Data(bytes)))
                        } else {
                            values.append(.null)
                        }
                    } else {
                        values.append(.null)
                    }
                } else {
                    values.append(.null)
                }
            }
            resultRows.append(values)
        }

        if columns.isEmpty, let probeSQL = Self.normalizedSelectForColumnProbe(sql) {
            columns = try await queryColumnNames(for: probeSQL, params: params ?? [])
        }

        return QueryResult(columns: columns, rows: resultRows, rowsAffected: 0)
    }

    public func beginTransaction() async throws -> any DatabaseTransaction {
        guard let conn else { throw DatabaseError.connectionFailed("Not connected") }
        _ = try await conn.simpleQuery("BEGIN").get()
        return MySQLTransaction(connection: self)
    }

    public func close() async {
        guard let conn else { return }
        try? await conn.close().get()
        self.conn = nil
        try? await group.shutdownGracefully()
    }

    public func isAlive() async -> Bool {
        guard let conn else { return false }
        return !conn.isClosed
    }

    private func toMySQLData(_ params: [DatabaseValue]) -> [MySQLData] {
        params.map { value in
            switch value {
            case .integer(let int): return MySQLData(int: int)
            case .double(let double): return MySQLData(double: double)
            case .string(let string): return MySQLData(string: string)
            case .bool(let bool): return MySQLData(bool: bool)
            case .data(let data):
                return MySQLData(type: .blob, buffer: ByteBuffer(bytes: data))
            case .null:
                return .null
            }
        }
    }

    static func normalizedSelectForColumnProbe(_ sql: String) -> String? {
        var trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix(";") {
            trimmed.removeLast()
            trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !trimmed.contains(";") else { return nil }
        guard trimmed.range(of: #"^\s*select\b"#, options: [.regularExpression, .caseInsensitive]) != nil else {
            return nil
        }
        return trimmed
    }

    private func queryColumnNames(for sql: String, params: [DatabaseValue]) async throws -> [String] {
        guard let conn else { throw DatabaseError.connectionFailed("Not connected") }

        let tableName = "databasekit_column_probe_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        let tableIdentifier = quoteIdentifier(tableName)
        let createSQL = "CREATE TEMPORARY TABLE \(tableIdentifier) AS \(sql) LIMIT 0"

        do {
            _ = try await conn.query(createSQL, toMySQLData(params)).get()
            let rows = try await conn.query(
                """
                SELECT COLUMN_NAME
                FROM INFORMATION_SCHEMA.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE()
                    AND TABLE_NAME = ?
                ORDER BY ORDINAL_POSITION
                """,
                [MySQLData(string: tableName)]
            ).get()
            try await dropTemporaryTable(tableIdentifier)
            return rows.compactMap { row in
                row.column("COLUMN_NAME")?.string ?? row.column("column_name")?.string
            }
        } catch {
            try? await dropTemporaryTable(tableIdentifier)
            throw error
        }
    }

    private func dropTemporaryTable(_ tableIdentifier: String) async throws {
        guard let conn else { return }
        _ = try await conn.query("DROP TEMPORARY TABLE IF EXISTS \(tableIdentifier)").get()
    }

    private func quoteIdentifier(_ identifier: String) -> String {
        "`\(identifier.replacingOccurrences(of: "`", with: "``"))`"
    }
}

public final actor MySQLTransaction: DatabaseTransaction {
    private let connection: MySQLConnection
    private var completed = false

    init(connection: MySQLConnection) {
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
public final class MySQLDriver: DatabaseDriver, Sendable {
    public var type: DatabaseType { .mysql }

    public init() {}

    public func connect(config: DatabaseConfig) async throws -> any DatabaseConnection {
        throw DatabaseError.notImplemented
    }
}
#endif
