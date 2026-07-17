import Foundation
import LumiCoreKit

/// AgentTempStoragePlugin 的运行时桥接:持有 plugin 专属数据目录,
/// 供 `AgentTempStoragePluginLocalStore` / `TempFileStorageService` 读取
/// (替代旧的 nonisolated 镜像变量)。两个存储共用同一个 Bridge。
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

@MainActor
public extension AgentTempStoragePlugin {
    static func bootstrapFromLumiCoreIfNeeded(context: LumiPluginContext) {
        guard !didBootstrapFromLumiCore else { return }
        if let core = context.lumiCore {
            AgentTempStoragePluginRuntimeBridge.pluginDirectory = core.pluginDataDirectory(for: AgentTempStoragePluginRuntimeBridge.pluginName)
        }
        didBootstrapFromLumiCore = true
    }
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
