import Foundation
import LumiCoreKit

/// AppStoreConnectPlugin 的运行时桥接:持有 LumiCore 数据根目录 + plugin 专属子目录,
/// 供 `AppStoreConnectPluginLocalStore` / `ScreenshotImageCache` / `ConnectAPICache`
/// 等 nonisolated 单例读取(替代旧的 nonisolated 镜像变量)。
///
/// 三个存储共用同一个 Bridge,因为它们同属一个 plugin。
/// `pluginSubdirectory` 是 `core.pluginDataDirectory(for: "AppStoreConnectPlugin")` 的结果
/// (已 sanitize),供读取 pluginDataDirectory(for:) 语义的调用方使用。
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
    static func bootstrapFromLumiCoreIfNeeded(context: LumiPluginContext) {
        guard !didBootstrapFromLumiCore else { return }
        if let core = context.lumiCore {
            AppStoreConnectPluginRuntimeBridge.dataRootDirectory = core.storage.dataRootDirectory
            AppStoreConnectPluginRuntimeBridge.pluginSubdirectory = core.storage.pluginDataDirectory(for: AppStoreConnectPluginRuntimeBridge.pluginName)
        }
        didBootstrapFromLumiCore = true
    }
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
