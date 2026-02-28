import Foundation

#if canImport(MySQLNIO)
import MySQLNIO
import NIO
import Logging

/// MySQL 连接（基于 MySQLNIO）
actor MySQLConnection: DatabaseConnection {
    private let group: EventLoopGroup
    private var conn: MySQLNIO.MySQLConnection?
    private let logger = Logger(label: "Lumi.Database.MySQL")

    /// 初始化并建立连接
    init(host: String, port: Int, username: String, password: String?, database: String) async throws {
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        let socketAddress = try SocketAddress.makeAddressResolvingHost(host, port: port)
        
        // 修正 MySQLNIO 初始化
        // MySQLConnection.connect 返回的是 EventLoopFuture
        // 需要用 .get() 转换为 async
        let future = MySQLNIO.MySQLConnection.connect(
            to: socketAddress,
            username: username,
            database: database,
            password: password,
            tlsConfiguration: nil,
            serverHostname: nil,
            on: group.next()
        )
        self.conn = try await future.get()
    }

    /// 执行写入语句
    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        guard let conn = conn else { throw DatabaseError.connectionFailed("Not connected") }
        let rows = try await conn.query(sql, toMySQLData(params ?? [])).get()
        return rows.count
    }

    /// 执行查询语句
    func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult {
        guard let conn = conn else { throw DatabaseError.connectionFailed("Not connected") }
        let rows = try await conn.query(sql, toMySQLData(params ?? [])).get()

        var resultRows: [[DatabaseValue]] = []
        var columns: [String] = []

        if let first = rows.first {
            columns = first.columnDefinitions.map { $0.name }
        }

        for row in rows {
            var one: [DatabaseValue] = []
            for colDef in row.columnDefinitions {
                let data = row.column(colDef.name)
                if let d = data {
                    if let s = d.string { one.append(.string(s)) }
                    else if let i = d.int { one.append(.integer(i)) }
                    else if let f = d.double { one.append(.double(f)) }
                    else if let b = d.bool { one.append(.bool(b)) }
                    else if let buffer = d.buffer {
                        var buf = buffer
                        if let bytes = buf.readBytes(length: buf.readableBytes) {
                            one.append(.data(Data(bytes)))
                        } else {
                            one.append(.null)
                        }
                    } else {
                        one.append(.null)
                    }
                } else {
                    one.append(.null)
                }
            }
            resultRows.append(one)
        }

        return QueryResult(columns: columns, rows: resultRows, rowsAffected: 0)
    }

    /// 开启事务
    func beginTransaction() async throws -> DatabaseTransaction {
        guard let conn = conn else { throw DatabaseError.connectionFailed("Not connected") }
        _ = try await conn.simpleQuery("BEGIN").get()
        return MySQLTransaction(connection: self)
    }

    /// 关闭连接
    func close() async {
        guard let conn = conn else { return }
        _ = conn.close()
        self.conn = nil
        try? await group.shutdownGracefully()
    }

    /// 是否存活
    func isAlive() async -> Bool {
        guard let conn = conn else { return false }
        return !conn.isClosed
    }

    private func toMySQLData(_ params: [DatabaseValue]) throws -> [MySQLData] {
        return params.map { v in
            switch v {
            case .integer(let i): return MySQLData(int: i)
            case .double(let d): return MySQLData(double: d)
            case .string(let s): return MySQLData(string: s)
            case .bool(let b): return MySQLData(bool: b)
            case .data(let data):
            // MySQLData.init(buffer:) 需要 ByteBuffer
            // ByteBuffer.init(bytes:) 需要 Sequence
            // Argument 'type' must precede argument 'buffer'
            return MySQLData(type: .blob, buffer: ByteBuffer(bytes: data))
            case .null: return .null
            }
        }
    }
}

/// MySQL 事务（占位）
final actor MySQLTransaction: DatabaseTransaction {
    private let connection: MySQLConnection
    private var completed = false

    init(connection: MySQLConnection) {
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
