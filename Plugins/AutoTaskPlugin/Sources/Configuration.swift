import Foundation

/// 配置协议：解耦插件与 App 侧存储路径。
public protocol Configuration: Sendable {
    /// 插件数据库目录 URL
    func databaseDirectory() -> URL
}
