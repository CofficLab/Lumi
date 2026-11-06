import Foundation
import KernelCore
import ProviderDocsView
import ProviderLLMManager
import ProviderSettingView
import ProviderStorage
import LumiLoggingKit
import os

/// KernelCore lifecycle for the global selected-text action menu.
@MainActor
public final class TextActionsPlugin: SuperPlugin, PluginDataMigrating, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.text-actions", category: "TextActions")
    public let id = "com.coffic.lumi.plugin.text-actions"
    public let order = 275
    public let metadata = PluginMetadata(id: "com.coffic.lumi.plugin.text-actions", name: pluginLocalization.string("Text Actions"), description: pluginLocalization.string("Show copy, search, and translation actions for selected text in other macOS apps."), category: .system, stage: .preview, policy: .disabledByDefault)

    /// 历史实现把开关存在 `UserDefaults.standard`，未使用插件专属目录。
    /// 目录名未变过，无需版本根搬迁。
    public let legacyDataDirectoryNames: [String] = []

    /// 辅助功能权限状态，由设置页共享。
    ///
    /// 授权状态会在应用之外变化（系统授权弹窗、系统设置里的开关），
    /// 只能靠「应用重新激活」来重新读取。该监听随本对象生命周期存在，
    /// 因此状态对象必须由插件持有，而不是由设置页临时创建。
    private var permissionState: TextActionsPermissionState?

    public init() {}

    /// 读取旧版开关所在的 UserDefaults 域。
    ///
    /// 抽成可替换的入口，便于单测注入假域：测试进程里 `Bundle.main`
    /// 是 xctest 可执行文件（没有 bundle identifier），拿不到 app 的持久化域。
    nonisolated(unsafe) static var legacyDefaultsDomainProvider: () -> [String: Any]? = {
        UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
    }

    /// 把 `UserDefaults.standard` 中的旧开关导入插件专属存储。
    ///
    /// 仅在插件存储尚无该键时导入，避免覆盖用户后续在设置页的修改。
    /// `UserDefaults` 原 key 保留，便于回退。
    public func migrateData(context: PluginDataMigrationContext) throws {
        let key = "TextActions.enabled"
        guard let domain = Self.legacyDefaultsDomainProvider(),
              let legacyValue = domain[key] as? Bool
        else {
            return
        }

        let directory = context.currentPluginDataDirectory
        let store = TextActionsPluginLocalStore(settingsDirectory: directory)
        guard store.object(forKey: key) == nil else { return }
        store.set(legacyValue, forKey: key)
        Self.logger.info("\(Self.t)Imported legacy TextActions.enabled from UserDefaults: \(legacyValue)")
    }

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) { TextActionsAboutView() })
            docs.addManual(DocsEntry(id: id, name: metadata.name) { TextActionsManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 存储目录注入必须早于 TextActionsPluginLocalStore.shared 的首次访问。
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            TextActionsRuntime.configure(settingsDirectory: storage.pluginDataDirectory(for: id))
        }
        if let llm = kernel.resolveProvider((any LLMManaging).self) { TextActionMenuController.shared.configure(translationProvider: llm) }
        // 权限状态由插件持有，设置页只读它——授权状态在应用外部变化
        // （系统弹窗、系统设置开关），只有插件级对象能持续监听到。
        let permissionState = TextActionsPermissionState()
        // 用户在系统设置里打开权限后，必须补启动选区监听，否则划词功能
        // 仍然不工作，且没有任何报错。
        permissionState.onPermissionGranted = { [weak self] in
            guard self != nil, TextActionsSettings.isEnabled else { return }
            TextSelectionManager.shared.startMonitoring()
        }
        self.permissionState = permissionState
        kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([SettingEntryItem(id: id, title: metadata.name, systemImage: "text.cursor", order: order) { TextActionsSettingsView(permissionState: permissionState) }])
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        if TextActionsSettings.isEnabled { TextSelectionManager.shared.startMonitoring() }
    }

    public func onDisable(kernel: KernelCoreContainer) async throws {
        TextSelectionManager.shared.stopMonitoring()
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        TextSelectionManager.shared.stopMonitoring()
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: [id])
        // 摘掉权限状态的应用激活监听，并释放状态对象。
        permissionState?.stop()
        permissionState = nil
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
