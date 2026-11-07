import KernelCore
import ProviderDocsView
import ProviderPluginManaging
import ProviderPromptSuggestion
import ProviderSettingView
import SwiftUI
import LumiLoggingKit
import os

/// 插件管理插件
@MainActor
public final class PluginPluginManager: SuperPlugin, SuperLog {
    /// 默认插件标识。宿主可在装配时传入自己的 id。
    public static let defaultPluginID = "com.coffic.lumi.plugin.plugin-manager"

    /// 插件唯一标识。宿主可注入自己的品牌 id。
    public let id: String
    public let order = 90

    public let metadata: PluginMetadata

    /// 日志子系统跟随插件 id，便于宿主在系统日志中区分品牌。
    nonisolated let logger: Logger

    private var generatedAboutPluginIDs: [String] = []

    /// `SettingEntryItem` 的稳定 ID，供设置深链和入口注册共同使用。
    static let settingsEntryID = "plugin-manager"

    private var capability: PluginManagementCapabilityAdapter?
    private var viewModel: PluginManagementViewModel?
    private var observer: PluginManagementObserver?

    /// 设置 Provider 的引用。入口在 `onReady` 注册（见 `onBoot` 注释）。
    private var settingsProvider: (any SettingViewProviding)?

    /// 「插件管理」入口当前是否已注册。用于让入口的增删保持幂等。
    private var isSettingsEntryRegistered = false

    /// 入口可见性策略。
    public enum EntryVisibility: Sendable {
        /// 仅当宿主存在**用户可配置**的插件时才注册入口（默认）。
        ///
        /// 插件管理页只列出用户可配置的插件（`policy.isConfigurable`，即
        /// `enabledByDefault` / `disabledByDefault`）。宿主若没有这类插件，
        /// 这个页面必然是一个永远为空的列表 —— 这样的入口对用户没有意义，
        /// 反而让人以为功能坏了。此时跳过注册。
        ///
        /// 这是默认策略：宿主**零配置**即可得到正确行为。宿主将来加入可配置
        /// 插件时，入口会自动出现（无需回来改 Factory）。
        case onlyWhenConfigurablePluginsExist
        /// 始终注册「插件管理」入口。
        ///
        /// 仅在宿主明知自己没有可配置插件、却仍要保留这个入口时使用
        /// （例如入口本身承载别的用途）。绝大多数情况不需要显式传这个值。
        case always
    }

    /// 入口可见性策略。默认 `.onlyWhenConfigurablePluginsExist`，宿主零配置。
    public let entryVisibility: EntryVisibility

    /// 插件自身的启用策略。
    ///
    /// 默认 `.required`：插件管理器是其它插件启停的观察者与呈现者，
    /// 自身被停用会让用户失去管理插件的入口。
    ///
    /// 宿主若明确不希望这个插件进入内核（连同它贡献的「插件管理」设置
    /// 入口一并消失），可传 `.disabled` —— 内核启动时会彻底排除它。
    public let policy: PluginEnablePolicy

    /// 创建插件管理插件。
    ///
    /// - Parameters:
    ///   - id: 插件唯一标识，决定 `PluginMetadata.id` 与日志子系统。
    ///   - entryVisibility: 「插件管理」设置入口的可见性策略。
    ///   - policy: 插件自身的启用策略。
    public init(
        id: String = PluginPluginManager.defaultPluginID,
        entryVisibility: EntryVisibility = .onlyWhenConfigurablePluginsExist,
        policy: PluginEnablePolicy = .required
    ) {
        self.id = id
        self.entryVisibility = entryVisibility
        self.policy = policy
        self.metadata = PluginMetadata(
            id: id,
            name: pluginLocalization.string("Plugin Manager"),
            description: pluginLocalization.string("Manage all registered plugins."),
            version: "1.0.0",
            category: .system,
            stage: .stable,
            policy: policy
        )
        self.logger = Logger(subsystem: id, category: "PluginManager")
    }

    private var promptSuggestion: PromptSuggestion {
        PromptSuggestion(
            id: "\(id).browse",
            title: pluginLocalization.string("Browse Plugins"),
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
        // 提示建议的注册推迟到 `onReady`：它深链到「插件管理」设置入口，
        // 而入口是否注册取决于宿主的插件策略（`entryVisibility`），此时还
        // 不知道全部插件是否已就绪。
        kernel.resolveProvider((any DocsViewProviding).self)?.addManual(
            DocsEntry(id: id, name: metadata.name) { PluginManagerManualView() }
        )
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            logger.error("\(Self.t) SettingViewProviding not found")
            return
        }

        guard let manager = kernel.resolveProvider((any PluginManaging).self) else {
            logger.error("\(Self.t) PluginManaging not found")
            return
        }

        // 捕获 docs/provider 引用，供插件管理详情面板展示各插件的 about 视图。
        let docsProvider = kernel.resolveProvider((any DocsViewProviding).self)
        if docsProvider == nil {
            logger.error("\(Self.t) DocsViewProviding not found")
        }

        let capability = PluginManagementCapabilityAdapter(manager: manager)
        let viewModel = PluginManagementViewModel(
            capability: capability,
            docsCapability: PluginManagerDocsCapabilityAdapter(docs: docsProvider)
        )
        observer?.cancel()
        observer = PluginManagementObserver(
            capability: capability,
            viewModel: viewModel,
            subsystem: id
        )
        self.capability = capability
        self.viewModel = viewModel

        // 「插件管理」入口在 `onReady` 注册，而不是这里：`entryVisibility`
        // 需要依据**全部**插件的策略判断，而 `onBoot` 阶段 order 更大的插件
        // 尚未注册（见 `KernelCoreContainer.start` —— 先全部注册，再逐个 onBoot）。
        // 这里只把设置 Provider 的解析结果留到 onReady 使用。
        self.settingsProvider = settings
    }

    public func onReady(kernel: KernelCoreContainer) throws {
        // `onBoot` runs in plugin order. Plugins with a later order may not have
        // been registered when the settings ViewModel first snapshots the list.
        // Refresh after every plugin has completed Boot so the settings page
        // sees the complete registry, matching the old live Provider lookup.
        viewModel?.refresh()

        // 按可见性策略决定是否注册「插件管理」入口。
        //
        // 判断在 `onReady` 阶段进行：此刻全部插件已注册完毕。`onBoot` 阶段
        // order 更大的插件尚未注册（见 `KernelCoreContainer.start` —— 先全部
        // 注册，再逐个 onBoot），据此判断会漏掉插件。
        updateSettingsEntryVisibility(kernel: kernel)

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

    /// 按当前可见性策略注册「插件管理」设置入口，并同步提示建议。
    ///
    /// 幂等：状态不变时不重复操作。
    private func updateSettingsEntryVisibility(kernel: KernelCoreContainer) {
        guard let viewModel, let settings = settingsProvider else { return }

        let shouldRegister = shouldRegisterSettingsEntry(kernel: kernel)
        guard shouldRegister != isSettingsEntryRegistered else { return }

        if shouldRegister {
            let entry = SettingEntryItem(
                id: Self.settingsEntryID,
                title: pluginLocalization.string("Plugin Manager"),
                systemImage: "puzzlepiece.extension",
                order: 3
            ) { [viewModel] in
                PluginManagementView(viewModel: viewModel)
            }
            settings.addEntries([entry])
            isSettingsEntryRegistered = true
            // 入口存在时，「浏览插件」提示建议才有意义（它深链到这个入口）。
            registerPromptSuggestion(kernel: kernel, requiresEnable: false)
        } else {
            settings.removeEntries(ids: [Self.settingsEntryID])
            isSettingsEntryRegistered = false
            // 入口不存在时撤掉提示建议，否则用户点「浏览插件」会深链到一个
            // 不存在的设置页。
            kernel.resolveProvider((any PromptSuggestionProviding).self)?
                .unregister(id: promptSuggestion.id)
        }
    }

    /// 是否应注册「插件管理」设置入口。
    private func shouldRegisterSettingsEntry(kernel: KernelCoreContainer) -> Bool {
        switch entryVisibility {
        case .onlyWhenConfigurablePluginsExist:
            return kernel.allPlugins.contains { $0.metadata.policy.isConfigurable }
        case .always:
            return true
        }
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        // 提示建议跟随入口：入口不存在时，深链无处可去。
        if isSettingsEntryRegistered {
            registerPromptSuggestion(kernel: kernel, requiresEnable: false)
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        observer?.cancel()
        observer = nil
        viewModel = nil
        capability = nil
        settingsProvider = nil
        isSettingsEntryRegistered = false
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: [Self.settingsEntryID])

        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            // DocsViewProviding predates Kernel contribution ownership, so
            // most plugins add their entries directly and do not have a
            // token for KernelCore to revoke. At this point the kernel is
            // stopping all plugins; clear the complete plugin-owned snapshot
            // so a stopped kernel cannot expose stale About/Manual entries.
            docs.replaceAboutEntries([])
            docs.replaceManualEntries([])
        }
        generatedAboutPluginIDs.removeAll()
    }

    public func onDisable(kernel: KernelCoreContainer) async throws {
        // 提示建议跟随入口：入口不存在时，深链无处可去。
        if isSettingsEntryRegistered {
            registerPromptSuggestion(kernel: kernel, requiresEnable: true)
        }
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any PromptSuggestionProviding).self)?.unregister(id: promptSuggestion.id)
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
