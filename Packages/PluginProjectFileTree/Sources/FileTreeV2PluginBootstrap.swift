import Foundation

/// ProjectFileTreePlugin 的运行时桥接:持有 Storage service 解析出的插件目录,
/// 供 `FileTreeSettings` 读取(持久化展开状态)。
enum ProjectFileTreePluginRuntimeBridge {
    nonisolated(unsafe) static var pluginDirectory: URL?

    static let pluginName = "ProjectFileTree"
}
