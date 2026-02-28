import Foundation

/// Redis 驱动工厂
/// 使用 Network 框架建立与 Redis 的 TCP 连接，支持基础命令：PING/GET/SET/SCAN。
final class RedisDriver: DatabaseDriver, Sendable {
    var type: DatabaseType { .redis }
    
    /// 创建 Redis 连接
    /// - Parameter config: 需要 host/port，password 可选
    /// - Returns: Redis 连接
    /// - Throws: 配置错误或网络错误
    func connect(config: DatabaseConfig) async throws -> DatabaseConnection {
        guard let host = config.host, !host.isEmpty else {
            throw DatabaseError.invalidConfiguration("Redis 需要有效的主机地址")
        }
        let port = config.port ?? 6379
        return try await RedisConnection(host: host, port: port, password: config.password)
    }
}
