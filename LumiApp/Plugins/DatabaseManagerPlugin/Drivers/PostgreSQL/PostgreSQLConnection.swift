import Foundation

#if canImport(PostgresNIO)
import PostgresNIO

/// PostgreSQL 连接（占位适配：启用依赖后可快速替换为真实实现）
actor PGConnection: DatabaseConnection {
    /// 初始化（当前不建立真实连接，保持编译安全）
    /// - Parameters:
    ///   - host: 主机地址
    ///   - port: 端口
    ///   - username: 用户名
    ///   - password: 密码
    ///   - database: 数据库名
    init(host: String, port: Int, username: String, password: String?, database: String) {
    }
    
    /// 执行写入语句
    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        throw DatabaseError.notImplemented
    }
    
    /// 执行查询语句
    func query(_ sql: String, params: [DatabaseValue]?) async throws -> QueryResult {
        throw DatabaseError.notImplemented
    }
    
    /// 开启事务
    func beginTransaction() async throws -> DatabaseTransaction {
        throw DatabaseError.notImplemented
    }
    
    /// 关闭连接
    func close() async {
    }
    
    /// 是否存活
    func isAlive() async -> Bool {
        false
    }
}

/// PostgreSQL 事务（占位）
final actor PGTransaction: DatabaseTransaction {
    func commit() async throws {
        throw DatabaseError.notImplemented
    }
    func rollback() async throws {
        throw DatabaseError.notImplemented
    }
    func execute(_ sql: String, params: [DatabaseValue]?) async throws -> Int {
        throw DatabaseError.notImplemented
    }
}
#endif
