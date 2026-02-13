import Foundation

/// MySQL 驱动工厂
/// 负责根据配置创建 MySQL 连接。当前实现仅进行配置校验，实际网络连接后续将接入 MySQLNIO。
final class MySQLDriver: DatabaseDriver, Sendable {
    var type: DatabaseType { .mysql }
    
    /// 创建连接
    /// - Parameter config: 数据库配置（需包含 host/port/database/username/password）
    /// - Returns: 数据库连接实例
    /// - Throws: 配置错误或暂未实现错误
    func connect(config: DatabaseConfig) async throws -> DatabaseConnection {
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
        // 密码可以为空（例如使用无密码的本地调试），此处不强制
        #if canImport(MySQLNIO)
        return try MySQLConnection(host: host, port: port, username: user, password: config.password, database: config.database)
        #else
        throw DatabaseError.notImplemented
        #endif
    }
}
