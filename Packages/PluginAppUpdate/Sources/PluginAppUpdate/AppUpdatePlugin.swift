import Foundation
import KernelCore
import ProviderAppUpdate
import ProviderNetwork
import ProviderStorage

/// Lumi distribution-level update bootstrap.
///
/// Sparkle is deliberately host-owned rather than registered in
/// `FactoryLumi`'s generic plugin catalog: App Store builds must not link an
/// in-app updater. The Lumi host invokes this once after its V2 kernel has
/// registered `NetworkProviding`, preserving the old plugin's boot behavior.
@MainActor
public enum AppUpdateBootstrap {
    /// 插件数据目录所用的 pluginID。该插件不注册进 Kernel 插件目录，
    /// 自行声明以保持与存储目录一致。
    static let pluginID = "com.coffic.lumi.plugin.app-update"

    private static var requestObserver: UpdateRequestObserver?
    private static weak var registeredKernel: KernelCoreContainer?

    public static func start(kernel: KernelCoreContainer) {
        // 存储目录注入必须早于 UpdateService.shared 的首次访问（其 init 会读取通道）。
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            let directory = storage.pluginDataDirectory(for: pluginID)
            AppUpdateRuntime.configure(settingsDirectory: directory)
            importLegacyChannelIfNeeded(to: directory)
        }
        let service = UpdateService.shared
        // This is a host-owned provider: the updater is intentionally not
        // part of the generic plugin catalog, but settings can still use the
        // typed contract without importing Sparkle. Register it even for Debug
        // builds; Debug keeps update checks disabled, but the channel setting
        // should remain visible and testable in an Xcode-built app.
        if registeredKernel !== kernel {
            registeredKernel?.unregisterProvider((any AppUpdateChannelProviding).self)
            try? kernel.registerHostProvider((any AppUpdateChannelProviding).self, service)
            registeredKernel = kernel
        }
        requestObserver?.cancel()
        requestObserver = UpdateRequestObserver(
            onCheckForUpdates: { [weak service] in service?.checkForUpdates() },
            onInstallPreparedUpdate: { [weak service] in service?.handleInstallPreparedAppUpdateRequest() }
        )
        if let network = kernel.resolveProvider((any NetworkProviding).self) {
            service.configure(network: network)
        }
        service.setupFeedURLIfNeeded()
    }

    public static func stop() {
        requestObserver?.cancel()
        requestObserver = nil
        registeredKernel?.unregisterProvider((any AppUpdateChannelProviding).self)
        registeredKernel = nil
    }

    /// 更新通道此前存在 `UserDefaults.standard`，仅在插件存储尚无记录时导入。
    ///
    /// 该插件是 host-owned（不经 Kernel 的 PluginDataMigrating 流程），
    /// 因此在此处做一次性导入。`UserDefaults` 原 key 保留，便于回退。
    private static func importLegacyChannelIfNeeded(to directory: URL) {
        guard let rawValue = UserDefaults.standard.string(forKey: AppUpdateChannel.userDefaultsKey),
              let channel = AppUpdateChannel(rawValue: rawValue)
        else {
            return
        }
        let settingsFile = directory.appendingPathComponent("settings.plist")
        guard !FileManager.default.fileExists(atPath: settingsFile.path) else { return }
        AppUpdatePluginLocalStore(settingsDirectory: directory).setChannel(channel)
    }
}
