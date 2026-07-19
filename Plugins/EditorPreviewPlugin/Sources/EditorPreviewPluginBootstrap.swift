import Foundation
import LumiKernel

/// EditorPreviewBottomPanelPlugin 的运行时桥接:持有 plugin 专属数据目录,
/// 供 `EditorPreviewStorage` 读取(替代旧的 nonisolated 镜像变量)。
enum EditorPreviewPluginRuntimeBridge {
    nonisolated(unsafe) static var pluginDirectory: URL?

    static let fallbackRootDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
    }()

    /// plugin 名,与 EditorPreviewStorage.pluginName 一致。
    static let pluginName = "EditorPreviewPlugin"
}