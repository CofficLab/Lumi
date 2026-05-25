import Foundation

/// AutoTask 配置协议
///
/// 用于解耦对 App 侧 `AppConfig` / `DBConfig` 的直接依赖。
/// 由 App 侧注册文件提供实现，将数据库路径注入到 Package 中。
public protocol AutoTaskConfiguration: Sendable {
    /// 插件数据库目录 URL
    ///
    /// 替代 `AppConfig.getDBFolderURL()` 的调用。
    func databaseDirectory() -> URL
}
