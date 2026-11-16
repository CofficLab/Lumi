import KernelCore
import LumiUI
import ProviderDiskCache
import ProviderSettingView
import SwiftUI
import LumiLoggingKit
import os

/// 缓存管理插件
///
/// 在设置视图中注册「缓存」入口：磁盘缓存总占用、按插件分桶明细、
/// 单桶清空与全部清空。消费 `DiskCacheProviding` 的管理 API
/// （usageReport / clearAll / bucket.clear），是缓存治理的首个用户界面。
///
/// 缓存是「删了也不影响」的加速数据：清空只是让内容按需重新下载或重建。
@MainActor
public final class CacheManagerPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.cache-manager", category: "CacheManager")
    public let id = "com.coffic.lumi.plugin.cache-manager"
    public let order = 120
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.cache-manager",
        name: pluginLocalization.string("Cache Manager"),
        description: pluginLocalization.string("Manages Lumi's disposable disk cache: usage breakdown and cleanup."),
        category: .system,
        stage: .stable,
        policy: .alwaysOn
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            // 设置视图未注册：优雅降级，不贡献入口。
            return
        }
        guard let cache = kernel.resolveProvider((any DiskCacheProviding).self) else {
            Self.logger.error("\(Self.t)DiskCacheProviding not registered; cache manager entry skipped")
            return
        }

        let entry = SettingEntryItem(
            id: "cache-manager",
            title: pluginLocalization.string("Cache"),
            systemImage: "shippingbox",
            order: 60
        ) { [cache] in
            CacheManagerDetailView(viewModel: CacheManagerViewModel(cache: cache))
        }

        settings.addEntries([entry])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["cache-manager"])
    }
}