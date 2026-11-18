import Foundation

#if canImport(PostgresNIO)
import Logging
import NIOCore
import NIOPosix
import NIOSSL
import PostgresNIO

public final class PostgreSQLDriver: DatabaseDriver, Sendable {
    public var type: DatabaseType { .postgresql }

    public init() {}

    public func connect(config: DatabaseConfig) async throws -> any DatabaseConnection {
        guard let host = config.host, !host.isEmpty else {
            throw DatabaseError.invalidConfiguration("PostgreSQL 需要有效的主机地址")
        }
        let port = try config.validatedNetworkPort(serviceName: "PostgreSQL")
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
            database: config.database,
            sslOption: config.sslOption
        )
    }
}

public actor PGConnection: DatabaseConnection {
    private let group: EventLoopGroup
    private let conn: PostgresConnection
    private let logger = Logger(label: "com.lumi.postgres")

    public init(host: String, port: Int, username: String, password: String?, database: String, sslOption: ConnectionSSLOption? = nil) async throws {
        group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        let tls: PostgresConnection.Configuration.TLS
        switch sslOption {
        case nil, .disable:
            tls = .disable
        case .prefer:
            // prefer：尽量加密，握手失败则回退明文（postgres-nio 内部处理回退）。
            let ctx = try NIOSSLContext(configuration: sslOption!.makeTLSConfiguration())
            tls = .prefer(ctx)
        case .require, .verifyCA, .verifyFull:
            // require/verify-ca/verify-full：强制加密，证书校验强度由 makeTLSConfiguration 决定。
            // postgres-nio 的 TLS 枚举没有 verifyFull case，校验差异通过 TLSConfiguration 表达。
            let ctx = try NIOSSLContext(configuration: sslOption!.makeTLSConfiguration())
            tls = .require(ctx)
        }

        let config = PostgresConnection.Configuration(
            host: host,
            port: port,
            username: username,
            password: password ?? "",
            database: database,
            tls: tls
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

        // 列名取自服务器先于数据行发来的 RowDescription，零行结果同样携带
        // （#278）：不再需要「临时表探针」重跑用户 SQL，也避免探针在
        // autocommit 下引用已被 ON COMMIT DROP 掉的表导致整个查询失败。
        let pgColumns = rowSequence.columns.map(\.name)
        var resultRows: [[DatabaseValue]] = []

        for try await row in rowSequence {
            var values: [DatabaseValue] = []
            for cell in row {
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

        return QueryResult(columns: pgColumns, rows: resultRows, rowsAffected: resultRows.count)
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
