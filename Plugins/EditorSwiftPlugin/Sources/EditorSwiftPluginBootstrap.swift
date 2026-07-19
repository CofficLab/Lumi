import Foundation
import LumiCoreKit

/// EditorSwiftPlugin 的运行时桥接:持有 LumiCore 数据根目录 + plugin 专属子目录,
/// 供 `EditorSwiftBuildServerStore` 读取(替代旧的 nonisolated 镜像变量)。
enum EditorSwiftPluginRuntimeBridge {
    nonisolated(unsafe) static var dataRootDirectory: URL?

    nonisolated(unsafe) static var pluginSubdirectory: URL?

    static let pluginName = "EditorSwiftPlugin"

    static let fallbackRootDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
    }()
}

@MainActor
public extension EditorSwiftPlugin {
    static func bootstrapFromLumiCoreIfNeeded(context: any LumiCoreAccessing) {
        guard !didBootstrapFromLumiCore else { return }
        if let core = context.lumiCore {
            EditorSwiftPluginRuntimeBridge.dataRootDirectory = core.storage.dataRootDirectory
            EditorSwiftPluginRuntimeBridge.pluginSubdirectory = core.storage.pluginDataDirectory(for: EditorSwiftPluginRuntimeBridge.pluginName)
        }
        didBootstrapFromLumiCore = true
    }
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
