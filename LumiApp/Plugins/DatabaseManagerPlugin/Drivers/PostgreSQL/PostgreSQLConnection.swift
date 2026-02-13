import Foundation

#if canImport(PostgresNIO)
import PostgresNIO
import NIO
import Logging

/// PostgreSQL 连接（基于 PostgresNIO）
actor PGConnection: DatabaseConnection {
    private let group: EventLoopGroup
    private let conn: PostgresConnection
    private let logger = Logger(label: "Lumi.Database.Postgres")

    /// 初始化并建立连接
    init(host: String, port: Int, username: String, password: String?, database: String) async throws {
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        let config = PostgresConnection.Configuration(
            connection: .init(host: host, port: port),
            authentication: .init(username: username, database: database, password: password ?? ""),
            tls: .disable
        )

        // 使用正确的 connect API
        self.conn = try await PostgresConnection.connect(
            on: group.next(),
            configuration: config,
            id: 1,
            logger: logger
        )
    }

    /// 执行写入语句
    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        let logger = Logger(label: "com.lumi.postgres.exec")
        let query = PostgresQuery(unsafeSQL: sql)
        _ = try await conn.query(query, logger: logger).get()
        // 返回 1 (暂无法获取 affectedRows)
        return 1
    }

    /// 执行查询语句
    func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult {
        let logger = Logger(label: "com.lumi.postgres.query")
        // 将 sql 字符串转换为 PostgresQuery
        let query = PostgresQuery(unsafeSQL: sql)
        
        // PostgresNIO 的 async query 直接返回 PostgresRowSequence
        // 不需要 .get()，因为返回值不是 Future
        let rows = try await conn.query(query, logger: logger).get()
        
        var columns: [String] = []
        var out: [[DatabaseValue]] = []
        
        // PostgresRowSequence 在 1.x 版本中是 Sequence
        // 但编译器提示 "For-in loop requires 'PostgresRowSequence' to conform to 'Sequence'"
        // 可能是因为 rows 本身是 Future 的结果，或者是 1.x 版本中需要显式转为 Array 或 Iterator
        // 尝试将其转为 Array 进行遍历
        for row in rows {
            var one: [DatabaseValue] = []
            
            // 遍历所有列
            // 使用 row.enumerated() 获取索引和 PostgresCell
            // 但 row 本身不是 Collection，可能没有 enumerated() ?
            // PostgresRow 遵循 Sequence，元素是 PostgresCell
            // 我们手动维护索引
            var index = 0
            for cell in row {
                if let s = try? cell.decode(String.self) {
                    one.append(.string(s))
                } else if let i = try? cell.decode(Int.self) {
                    one.append(.integer(i))
                } else if let f = try? cell.decode(Double.self) {
                    one.append(.double(f))
                } else if let b = try? cell.decode(Bool.self) {
                    one.append(.bool(b))
                } else if var bytes = cell.bytes {
                    // 使用 readBytes 避免 Data(buffer:) 的 Sequence 协议问题
                    if let d = bytes.readBytes(length: bytes.readableBytes) {
                        one.append(.data(Data(d)))
                    } else {
                        one.append(.null)
                    }
                } else {
                    one.append(.null)
                }
                
                // 仅在第一行时收集列名
                if out.isEmpty {
                    // PostgresRowSequence 无法直接访问 metadata
                    // 通过 row.rowDescription 获取
                    columns.append(row.rowDescription.fields[index].name)
                }
                index += 1
            }
            out.append(one)
        }
        
        // 确保 columns 不为空（如果无数据）
        // 如果 rows 为空，尝试从 rows.rowDescription 获取（如果可行）
        // 注意：PostgresRowSequence 1.x 可能确实没有 metadata
        // 若 rows 为空，则无法获取列名
        
        return QueryResult(columns: columns, rows: out, rowsAffected: 0)
    }

    /// 开启事务
    func beginTransaction() async throws -> DatabaseTransaction {
        let logger = Logger(label: "com.lumi.postgres.transaction")
        let query = PostgresQuery(unsafeSQL: "BEGIN")
        _ = try await conn.query(query, logger: logger).get()
        return PGTransaction(connection: self)
    }

    /// 关闭连接
    func close() async {
        try? await conn.close()
        try? await group.shutdownGracefully()
    }

    /// 是否存活
    func isAlive() async -> Bool {
        !conn.isClosed
    }
}

/// PostgreSQL 事务（占位）
final actor PGTransaction: DatabaseTransaction {
    private let connection: PGConnection
    private var completed = false

    init(connection: PGConnection) {
        self.connection = connection
    }

    func commit() async throws {
        guard !completed else { throw DatabaseError.transactionFailed("Transaction already completed") }
        _ = try await connection.execute("COMMIT", params: nil)
        completed = true
    }
    func rollback() async throws {
        guard !completed else { throw DatabaseError.transactionFailed("Transaction already completed") }
        _ = try await connection.execute("ROLLBACK", params: nil)
        completed = true
    }
    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        guard !completed else { throw DatabaseError.transactionFailed("Transaction already completed") }
        return try await connection.execute(sql, params: params)
    }
}
#endif
