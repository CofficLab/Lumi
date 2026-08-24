import Foundation
import KernelLumi

/// EditorSwiftPlugin 的运行时桥接:持有 Storage service 解析出的插件目录,
/// 供 `EditorSwiftBuildServerStore` 读取。
enum EditorSwiftPluginRuntimeBridge {
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
    static func bootstrapFromLumiCoreIfNeeded(kernel: KernelLumi) {
        guard !didBootstrapFromLumiCore else { return }
        if let storage = kernel.storage {
            EditorSwiftPluginRuntimeBridge.pluginSubdirectory =
                storage.pluginDataDirectory(for: EditorSwiftPluginRuntimeBridge.pluginName)
        }
        didBootstrapFromLumiCore = true
    }
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
