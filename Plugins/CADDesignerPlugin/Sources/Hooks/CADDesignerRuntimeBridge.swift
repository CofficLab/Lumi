import Foundation

/// CAD Designer 插件运行时桥接
///
/// 用于在 Agent Tools 中访问 CAD 运行时数据。
/// CADDocumentStore 使用单例模式,无需复杂引导。
@MainActor
public enum CADDesignerRuntimeBridge {
    nonisolated(unsafe) static var dataRootDirectory: URL?
    nonisolated(unsafe) static var pluginSubdirectory: URL?

    public static func configure(dataRootDirectory: URL, pluginSubdirectory: URL) {
        self.dataRootDirectory = dataRootDirectory
        self.pluginSubdirectory = pluginSubdirectory
    }

    public static var configuredPluginSubdirectory: URL? { pluginSubdirectory }
}
