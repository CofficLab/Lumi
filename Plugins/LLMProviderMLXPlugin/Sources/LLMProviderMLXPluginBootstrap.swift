import Foundation
import LumiCoreKit

/// LLMProviderMLXPlugin(MLX/MLXLumi) 的运行时桥接:持有 plugin 专属数据目录,
/// 供 `MLXModels.cacheRootDirectory` 读取(替代旧的 nonisolated 镜像变量)。
enum LLMProviderMLXPluginRuntimeBridge {
    nonisolated(unsafe) static var pluginSubdirectory: URL?

    static let pluginName = "LLMProviderMLX"

    static let fallbackRootDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
    }()
}

@MainActor
public extension MLXLumiPlugin {
    static func bootstrapFromLumiCoreIfNeeded(context: LumiPluginContext) {
        guard !didBootstrapFromLumiCore else { return }
        if let core = context.lumiCore {
            LLMProviderMLXPluginRuntimeBridge.pluginSubdirectory = core.storage.pluginDataDirectory(for: LLMProviderMLXPluginRuntimeBridge.pluginName)
        }
        didBootstrapFromLumiCore = true
    }
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
