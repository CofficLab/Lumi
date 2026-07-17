import Foundation
import LumiCoreKit

/// LayoutPlugin 的运行时桥接:持有 plugin 数据目录,供 `LayoutPluginLocalStore`
/// 等 nonisolated 单例在 init 里读取(替代旧的 nonisolated 镜像变量)。
///
/// `pluginDirectory` 由 `LayoutPlugin.bootstrapFromLumiCoreIfNeeded(context:)`
/// 在 @MainActor 上下文设置(此时从 `context.lumiCore.storage.pluginDataDirectory(for:)`
/// 读取路径不撞 actor 隔离)。在 bootstrap 完成前,读取方走 `fallbackRootDirectory`。
enum LayoutPluginRuntimeBridge {
    /// 由 bootstrap 注入的 LumiCore 数据根目录。注意:这是 dataRoot(不是 plugin 子目录),
    /// 与旧镜像 `currentLumiCoreDataRootDirectory` 语义一致——各 LocalStore 自己拼 plugin 名子目录。
    nonisolated(unsafe) static var pluginDirectory: URL?

    /// bootstrap 未完成时的兜底目录(`<AppSupport>/<bundleID>`)。
    /// 独立计算,不依赖 nonisolated 镜像。
    static let fallbackRootDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
    }()
}

@MainActor
public extension LayoutPlugin {
    /// 从 `LumiPluginContext.lumiCore` 读取数据根目录,注入 `LayoutPluginRuntimeBridge`。
    /// 幂等——首次调用后 `didBootstrapFromLumiCore` 置位,后续调用直接返回。
    static func bootstrapFromLumiCoreIfNeeded(context: LumiPluginContext) {
        guard !didBootstrapFromLumiCore else { return }
        if let core = context.lumiCore {
            LayoutPluginRuntimeBridge.pluginDirectory = core.storage.dataRootDirectory
        }
        didBootstrapFromLumiCore = true
    }
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
