import Foundation
import LumiCoreKit

/// AppManagerPlugin 的运行时桥接:持有 LumiCore 数据根目录,
/// 供 `CacheManager` 通过 `AppManagerPlugin.databaseRootURLProvider` 读取
/// (替代旧的 nonisolated 镜像变量)。
enum AppManagerPluginRuntimeBridge {
    nonisolated(unsafe) static var dataRootDirectory: URL?

    static let fallbackRootDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
    }()
}

@MainActor
public extension AppManagerPlugin {
    static func bootstrapFromLumiCoreIfNeeded(context: LumiPluginContext) {
        guard !didBootstrapFromLumiCore else { return }
        if let core = context.lumiCore {
            AppManagerPluginRuntimeBridge.dataRootDirectory = core.storage.dataRootDirectory
            // 覆盖 provider,让后续访问的 CacheManager 拿到真实路径。
            // 注意:若 CacheManager.shared 已在 bootstrap 前初始化,会留在 fallback 目录
            // (与旧镜像在该时序下行为一致)。
            AppManagerPlugin.databaseRootURLProvider = { core.storage.dataRootDirectory }
        }
        didBootstrapFromLumiCore = true
    }
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
