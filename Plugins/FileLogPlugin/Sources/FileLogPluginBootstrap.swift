import Foundation
import LumiCoreKit

/// FileLogPlugin 的运行时桥接:持有 plugin 专属数据目录,
/// 供 `DefaultFileLogConfiguration.logsDirectory()` 读取
/// (替代旧的 nonisolated 镜像变量)。
enum FileLogPluginRuntimeBridge {
    nonisolated(unsafe) static var pluginSubdirectory: URL?

    static let pluginName = "FileLog"

    static let fallbackRootDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
    }()
}

@MainActor
public extension FileLogPlugin {
    static func bootstrapFromLumiCoreIfNeeded(context: LumiPluginContext) {
        guard !didBootstrapFromLumiCore else { return }
        if let core = context.lumiCore {
            FileLogPluginRuntimeBridge.pluginSubdirectory = core.pluginDataDirectory(for: FileLogPluginRuntimeBridge.pluginName)
        }
        didBootstrapFromLumiCore = true
    }
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
