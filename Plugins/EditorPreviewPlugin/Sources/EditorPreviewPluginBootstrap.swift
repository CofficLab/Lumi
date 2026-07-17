import Foundation
import LumiCoreKit

/// EditorPreviewBottomPanelPlugin 的运行时桥接:持有 plugin 专属数据目录,
/// 供 `EditorPreviewStorage` 读取(替代旧的 nonisolated 镜像变量)。
///
/// 注意:这里存的是 **plugin 专属子目录**(即 `lumiCore.pluginDataDirectory(for:)` 的结果),
/// 与其他 plugin 的 Bridge 存 dataRoot 不同——因为 EditorPreviewStorage 原本读的就是
/// `lumiCorePluginDataDirectory(for: pluginName)`(已拼好 sanitize 后的子目录)。
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

@MainActor
public extension EditorPreviewBottomPanelPlugin {
    static func bootstrapFromLumiCoreIfNeeded(context: LumiPluginContext) {
        guard !didBootstrapFromLumiCore else { return }
        if let core = context.lumiCore {
            EditorPreviewPluginRuntimeBridge.pluginDirectory = core.storage.pluginDataDirectory(for: EditorPreviewPluginRuntimeBridge.pluginName)
        }
        didBootstrapFromLumiCore = true
    }
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
