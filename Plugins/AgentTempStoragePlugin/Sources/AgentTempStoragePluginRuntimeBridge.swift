import Foundation

/// AgentTempStoragePlugin 运行时桥接
///
/// 持有 plugin 专属数据目录,供 TempFileStorageService 和 AgentTempStoragePluginLocalStore 读取
enum AgentTempStoragePluginRuntimeBridge {
    nonisolated(unsafe) static var pluginDirectory: URL?

    static let pluginName = "AgentTempStorage"

    static let fallbackRootDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
    }()
}