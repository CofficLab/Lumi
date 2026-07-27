import Foundation
import LumiKernel

/// AppStoreConnectPlugin 的运行时桥接:持有 plugin 专属子目录,
/// 供 `AppStoreConnectPluginLocalStore` / `ScreenshotImageCache` / `ConnectAPICache`
/// 等 nonisolated 单例读取。
enum AppStoreConnectPluginRuntimeBridge {
    nonisolated(unsafe) static var dataRootDirectory: URL?
    nonisolated(unsafe) static var pluginSubdirectory: URL?

    static let pluginName = "AppStoreConnectPlugin"

    static let fallbackRootDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
    }()
}

@MainActor
public extension AppStoreConnectPlugin {
    static func bootstrapFromLumiCoreIfNeeded(kernel: LumiKernel) {
        guard !didBootstrapFromLumiCore else { return }
        if let storage = kernel.storage {
            AppStoreConnectPluginRuntimeBridge.dataRootDirectory = storage.dataRootDirectory
            AppStoreConnectPluginRuntimeBridge.pluginSubdirectory = storage.pluginDataDirectory(for: AppStoreConnectPluginRuntimeBridge.pluginName)
        }
        didBootstrapFromLumiCore = true
    }
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
