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
    private var selectionObserver: TextSelectionObserver?

    /// 历史实现把开关存在 `UserDefaults.standard`，未使用插件专属目录。
    /// 目录名未变过，无需版本根搬迁。
    public let legacyDataDirectoryNames: [String] = []

    public init() {}

    /// 把 `UserDefaults.standard` 中的旧开关导入插件专属存储。
    ///
    /// 仅在插件存储尚无该键时导入，避免覆盖用户后续在设置页的修改。
    /// `UserDefaults` 原 key 保留，便于回退。
    public func migrateData(context: PluginDataMigrationContext) throws {
        let key = "TextActions.enabled"
        guard let domain = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? ""),
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
        kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([SettingEntryItem(id: id, title: metadata.name, systemImage: "text.cursor", order: order) { TextActionsSettingsView() }])
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        if TextActionsSettings.isEnabled { selectionObserver = TextSelectionObserver() }
    }

    public func onDisable(kernel: KernelCoreContainer) async throws {
        selectionObserver?.cancel()
        selectionObserver = nil
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        selectionObserver?.cancel()
        selectionObserver = nil
        TextActionMenuController.shared.hide()
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: [id])
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
