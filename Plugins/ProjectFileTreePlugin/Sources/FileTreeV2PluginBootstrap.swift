import Foundation

/// ProjectFileTreePlugin 的运行时桥接:持有 Storage service 解析出的插件目录,
/// 供 `FileTreeSettings` 读取(持久化展开状态)。
enum ProjectFileTreePluginRuntimeBridge {
    nonisolated(unsafe) static var pluginDirectory: URL?

    static let fallbackRootDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
    }()
}
