import Foundation

#if canImport(MySQLNIO)
import Logging
import MySQLNIO
import NIOCore
import NIOPosix
import NIOSSL

public final class MySQLDriver: DatabaseDriver, Sendable {
    public var type: DatabaseType { .mysql }

    public init() {}

    public func connect(config: DatabaseConfig) async throws -> any DatabaseConnection {
        guard let host = config.host, !host.isEmpty else {
            throw DatabaseError.invalidConfiguration("MySQL 需要有效的主机地址")
        }
        let port = try config.validatedNetworkPort(serviceName: "MySQL")
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
            database: config.database,
            sslOption: config.sslOption
        )
    }
}

public actor MySQLConnection: DatabaseConnection {
    private let group: EventLoopGroup
    private var conn: MySQLNIO.MySQLConnection?

    public init(host: String, port: Int, username: String, password: String?, database: String, sslOption: ConnectionSSLOption? = nil) async throws {
        group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let socketAddress = try SocketAddress.makeAddressResolvingHost(host, port: port)
        let tlsConfiguration: TLSConfiguration? = {
            guard let ssl = sslOption, ssl.enablesTLS else { return nil }
            return ssl.makeTLSConfiguration()
        }()
        let future = MySQLNIO.MySQLConnection.connect(
            to: socketAddress,
            username: username,
            database: database,
            password: password,
            tlsConfiguration: tlsConfiguration,
            serverHostname: sslOption?.enablesTLS == true ? host : nil,
            on: group.next()
        )
        conn = try await future.get()
    }

    public func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        guard let conn else { throw DatabaseError.connectionFailed("Not connected") }
        let metadataStore = MySQLQueryMetadataStore()
        _ = try await conn.query(
            sql,
            toMySQLData(params ?? []),
            onMetadata: { metadata in
                metadataStore.setAffectedRows(Int(metadata.affectedRows))
            }
        ).get()
        return metadataStore.affectedRows
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
            resultRows.append(Self.decodeRow(row))
        }

        if columns.isEmpty, let probeSQL = Self.normalizedSelectForColumnProbe(sql) {
            columns = try await queryColumnNames(for: probeSQL, params: params ?? [])
        }

        return QueryResult(columns: columns, rows: resultRows, rowsAffected: 0)
    }

    /// 按位置解码一行。
    ///
    /// SQL 允许结果集中出现重复列名（如 `SELECT a.id, b.id` 或多表 JOIN），而
    /// mysql-nio 的 `row.column(name)` 按名字返回**首个**匹配列，会让后面的同名列
    /// 错显首列的值，界面静默展示错误数据（#585）。这里改用 `columnDefinitions`
    /// 与 `values` 的位置对应关系逐列构造 `MySQLData`，与列名是否重复无关。
    static func decodeRow(_ row: MySQLRow) -> [DatabaseValue] {
        var values: [DatabaseValue] = []
        for (colDef, buffer) in zip(row.columnDefinitions, row.values) {
            let data = MySQLData(
                type: colDef.columnType,
                format: row.format,
                buffer: buffer,
                isUnsigned: colDef.flags.contains(.COLUMN_UNSIGNED)
            )
            if let s = data.string { values.append(.string(s)) }
            else if let i = data.int { values.append(.integer(i)) }
            else if let f = data.double { values.append(.double(f)) }
            else if let b = data.bool { values.append(.bool(b)) }
            else if var buf = data.buffer {
                if let bytes = buf.readBytes(length: buf.readableBytes) {
                    values.append(.data(Data(bytes)))
                } else {
                    values.append(.null)
                }
            } else {
                values.append(.null)
            }
        }
        return values
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

    /// 零行结果时探测列名。
    ///
    /// MySQL 协议在零行时不会把列定义交给客户端，驱动拿不到列名。
    /// 这里用会话临时表复制查询结构，再读它的列定义。
    ///
    /// 注意：会话临时表**不**出现在 `INFORMATION_SCHEMA.COLUMNS` 中
    /// （该 catalog 只列永久表），所以必须用 `SHOW COLUMNS` 读取。
    private func queryColumnNames(for sql: String, params: [DatabaseValue]) async throws -> [String] {
        guard let conn else { throw DatabaseError.connectionFailed("Not connected") }

        let tableName = "databasekit_column_probe_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"
        let tableIdentifier = quoteIdentifier(tableName)
        let createSQL = "CREATE TEMPORARY TABLE \(tableIdentifier) AS \(sql) LIMIT 0"

        do {
            _ = try await conn.query(createSQL, toMySQLData(params)).get()
            let rows = try await conn.query("SHOW COLUMNS FROM \(tableIdentifier)").get()
            try await dropTemporaryTable(tableIdentifier)
            return rows.compactMap { row in
                row.column("Field")?.string ?? row.column("field")?.string
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

private final class MySQLQueryMetadataStore: @unchecked Sendable {
    private let lock = NSLock()
    private var _affectedRows = 0

    var affectedRows: Int {
        lock.lock()
        defer { lock.unlock() }
        return _affectedRows
    }

    func setAffectedRows(_ affectedRows: Int) {
        lock.lock()
        _affectedRows = affectedRows
        lock.unlock()
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
