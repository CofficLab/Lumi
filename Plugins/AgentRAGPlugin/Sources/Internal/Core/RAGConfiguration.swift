import Foundation

/// RAGKit 配置协议
///
/// 用于解耦对 MagicKit.AppConfig 的直接依赖。
/// Plugin 层提供适配器实现，将配置注入到 RAGKit 中。
public protocol RAGConfiguration: Sendable {
    /// 插件数据库目录 URL
    ///
    /// 替代 `currentLumiCore?.pluginDataDirectory(for:)` 的调用。
    func pluginDatabaseDirectory() -> URL

    /// 是否启用详细日志
    var verboseLogging: Bool { get }
}

/// 默认配置实现
///
/// 数据库目录使用临时目录，详细日志关闭。
public struct DefaultRAGConfiguration: RAGConfiguration, Sendable {
    public let verboseLogging: Bool

    public init(verboseLogging: Bool = false) {
        self.verboseLogging = verboseLogging
    }

    public func pluginDatabaseDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("RAGKit")
    }
}
