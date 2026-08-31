import KernelCore
import ProviderDocsView
import ProviderPluginManaging
import ProviderPromptSuggestion
import ProviderSettingView
import SwiftUI
import KitSuperLog
import os

/// 插件管理插件
@MainActor
public final class PluginPluginManager: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.plugin-manager", category: "PluginManager")
    public let id = "com.coffic.lumi.plugin.plugin-manager"
    public let order = 90

    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.plugin-manager",
        name: "插件管理",
        description: "管理所有已注册插件。",
        version: "1.0.0",
        category: .system,
        stage: .stable,
        policy: .required
    )

    private var generatedAboutPluginIDs: [String] = []

    /// `SettingEntryItem` 的稳定 ID，供设置深链和入口注册共同使用。
    static let settingsEntryID = "plugin-manager"

    public init() {}

    private var promptSuggestion: PromptSuggestion {
        PromptSuggestion(
            id: "\(id).browse",
            title: "浏览插件",
            order: order * 1000,
            systemImage: "puzzlepiece.extension",
            action: .openSettingsTab(Self.settingsEntryID),
            style: .additive
        )
    }

    private func registerPromptSuggestion(kernel: KernelCoreContainer, requiresEnable: Bool) {
        var suggestion = promptSuggestion
        suggestion.pluginID = id
        suggestion.requiresEnable = requiresEnable
        kernel.resolveProvider((any PromptSuggestionProviding).self)?.register(suggestion)
    }

    public func onRegister(kernel: KernelCoreContainer) throws {
        registerPromptSuggestion(kernel: kernel, requiresEnable: !kernel.isPluginEnabled(id: id))
        kernel.resolveProvider((any DocsViewProviding).self)?.addManual(
            DocsEntry(id: id, name: metadata.name) { PluginManagerManualView() }
        )
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            Self.logger.error("\(Self.t) SettingViewProviding not found")
            return
        }

        guard let manager = kernel.resolveProvider((any PluginManaging).self) else {
            Self.logger.error("\(Self.t) PluginManaging not found")
            return
        }

        // 捕获 docs/provider 引用，供插件管理详情面板展示各插件的 about 视图。
        let docsProvider = kernel.resolveProvider((any DocsViewProviding).self)
        if docsProvider == nil {
            Self.logger.error("\(Self.t) DocsViewProviding not found")
        }

        let entry = SettingEntryItem(
            id: Self.settingsEntryID,
            title: "插件管理",
            systemImage: "puzzlepiece.extension",
            order: 3
        ) { [manager, docsProvider] in
            PluginManagementView(manager: manager, docsProvider: docsProvider)
        }

        settings.addEntries([entry])
    }

    public func onReady(kernel: KernelCoreContainer) throws {
        registerPromptSuggestion(kernel: kernel, requiresEnable: false)

        // 确保每个已启动插件都有 AboutView。插件自己的品牌化页面优先，
        // 这里只为尚未贡献页面的插件补充统一的详细元信息页。
        guard let docs = kernel.resolveProvider((any DocsViewProviding).self) else { return }
        for plugin in kernel.allPlugins where !docs.aboutEntries.contains(where: { $0.id == plugin.id }) {
            let metadata = plugin.metadata
            let isEnabled = kernel.isPluginEnabled(id: plugin.id)
            docs.addAbout(DocsEntry(id: plugin.id, name: metadata.name) {
                PluginDefaultAboutView(metadata: metadata, isEnabled: isEnabled)
            })
            generatedAboutPluginIDs.append(plugin.id)
        }
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        registerPromptSuggestion(kernel: kernel, requiresEnable: false)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: [Self.settingsEntryID])

        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            for pluginID in generatedAboutPluginIDs {
                docs.removeEntries(id: pluginID)
            }
        }
        generatedAboutPluginIDs.removeAll()
    }

    public func onDisable(kernel: KernelCoreContainer) async throws {
        registerPromptSuggestion(kernel: kernel, requiresEnable: true)
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any PromptSuggestionProviding).self)?.unregister(id: promptSuggestion.id)
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
