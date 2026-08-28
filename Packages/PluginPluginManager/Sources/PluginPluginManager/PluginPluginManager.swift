import KernelCore
import ProviderDocsView
import ProviderPluginManaging
import ProviderPromptSuggestion
import ProviderSettingView
import SwiftUI

/// 插件管理插件
@MainActor
public final class PluginPluginManager: SuperPlugin {
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

    public init() {}

    private var promptSuggestion: PromptSuggestion {
        PromptSuggestion(
            id: "\(id).browse",
            title: "浏览插件",
            order: order * 1000,
            systemImage: "puzzlepiece.extension",
            action: .openSettingsTab(id),
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
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            // 设置视图未注册：优雅降级，不贡献入口。
            return
        }

        guard let manager = kernel.resolveProvider((any PluginManaging).self) else {
            return
        }

        // 捕获 docs/provider 引用，供插件管理详情面板展示各插件的 about 视图。
        let docsProvider = kernel.resolveProvider((any DocsViewProviding).self)

        let entry = SettingEntryItem(
            id: "plugin-manager",
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
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        registerPromptSuggestion(kernel: kernel, requiresEnable: false)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["plugin-manager"])
    }

    public func onDisable(kernel: KernelCoreContainer) async throws {
        registerPromptSuggestion(kernel: kernel, requiresEnable: true)
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any PromptSuggestionProviding).self)?.unregister(id: promptSuggestion.id)
    }
}
