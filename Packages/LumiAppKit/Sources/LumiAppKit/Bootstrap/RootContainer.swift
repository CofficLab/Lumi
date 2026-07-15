import LumiChatKit
import LumiCoreKit
import LumiPluginRegistry
import LumiUI
import SuperLogKit
import SwiftUI
import EditorService
import os

@MainActor
final class RootContainer: ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "bootstrap.root-container")
    nonisolated static let emoji = "🗂️"
    nonisolated static let verbose = false

    /// Safe accessor for `ChatService` from a given `LumiCore` instance.
    /// `LumiCore` is now an instantiable class (no longer a singleton),
    /// so callers must pass the instance they want to resolve from.
    static func checkedChatService(_ lumiCore: LumiCore) -> ChatService {
        guard let service = lumiCore.chatService as? ChatService else {
            fatalError("LumiCore.chatService must be ChatService. Got: \(String(describing: type(of: lumiCore.chatService))). Check LumiCoreService.setupChatService.")
        }
        return service
    }

    let lumiCore: LumiCore
    let lumiCoreService: LumiCoreService
    let pluginService: PluginService
    let editorCoreService: EditorCoreService
    let chatSectionCoordinator: ChatSectionCoordinator
    let lumiUIService: LumiUIService
    let menuBarService: MenuBarService

    /// Normal throwing initializer
    init() throws {
        LumiPluginRegistry.restoreLayoutEarly()
        self.pluginService = PluginService()
        let dataRootDirectory = StorageService.makeDataRootDirectory()
        let editorFactory: LumiCore.EditorBootstrapFactory<EditorCoreService> = { provider in
            guard let pluginService = provider as? PluginService else {
                fatalError("Editor factory 收到的 provider 不是 PluginService")
            }
            return EditorCoreService(
                pluginService: pluginService,
                recentProjects: { [] }
            )
        }

        self.lumiCoreService = try LumiCoreService(
            provider: pluginService,
            editorFactory: editorFactory,
            dataRootDirectory: dataRootDirectory
        )
        let lumiCore = lumiCoreService.lumiCore
        self.lumiCore = lumiCore

        // 通过服务表解析具体类型 EditorCoreService（LumiCore.boot 已在内部注册）。
        guard let editorService = lumiCore.resolveService(EditorCoreService.self) else {
            fatalError("LumiCore 服务表中未找到 EditorCoreService，请确认 LumiCoreService.init 的 editorFactory 已正确传递。")
        }
        self.editorCoreService = editorService
        // EditorCoreService 在 editorFactory 闭包里被创建时拿不到 lumiCore,
        // 这里通过 configure 补上,让它能读 projectState。
        editorService.configure(lumiCore: lumiCore)

        self.chatSectionCoordinator = ChatSectionCoordinator(
            chatService: Self.checkedChatService(lumiCore),
            databaseDirectory: lumiCoreService.coreDatabaseDirectory
        )

        self.lumiUIService = LumiUIService(pluginService: pluginService, lumiCore: lumiCore)
        self.menuBarService = MenuBarService(pluginService: pluginService, lumiCore: lumiCore)

        lumiCore.registerService(LumiCoreService.self, lumiCoreService)
        lumiCore.registerService(ChatSectionCoordinator.self, chatSectionCoordinator)
        lumiCore.registerService(LumiBottomPanelLayoutPresenting.self, lumiCore.layoutState ?? LumiLayoutState())
        lumiCore.registerService(LumiThemeServicing.self, lumiUIService)
        lumiCore.registerService((any LumiLLMProviderSettingsContributing).self, pluginService)

        self.lumiUIService.onThemesDidChange = { [weak self] in
            self?.editorCoreService.syncAppSyntaxThemes()
        }
        LumiUIThemeRegistry.shared.onSystemAppearanceDidChange = { [weak self] in
            self?.editorCoreService.syncAppSyntaxThemes()
        }

        UpdateService.shared.setupFeedURLIfNeeded()
        reloadChatPluginContributions()


        // 初始化插件启用状态跟踪
        self.pluginService.initializePluginStates()
        // 回调挂到 LumiPluginRegistry（PluginService.init 里已经注册的 UI 刷新回调会被覆盖，
        // 所以这里手动补一次 objectWillChange.send()，保证 SwiftUI 依然能收到刷新信号）。
        LumiPluginRegistry.onEnabledPluginsChanged = { [weak self] in
            guard let self else { return }
            if Self.verbose {
                Self.logger.info("\(Self.t)插件启用状态变化，刷新相关服务")
            }
            // 补回 PluginService.init 里设置的 UI 刷新职责
            self.pluginService.objectWillChange.send()
            // 运行期插件状态变更时重新注册工具贡献。
            // 工具名称唯一性已在 boot 阶段校验，此处不会抛出异常。
            self.reloadChatPluginContributions()
            self.lumiUIService.reloadThemes(from: self.pluginService)
            self.menuBarService.refresh()
            self.editorCoreService.reinstallExtensions()
        }

        // 连接插件生命周期回调，处理启用/禁用时的资源清理
        LumiPluginRegistry.onPluginLifecycleChange = { [weak self] (plugin, enabled) in
            guard self != nil else { return }
            if Self.verbose {
                Self.logger.info("\(Self.t)插件生命周期变化: \(plugin.info.id) -> \(enabled ? "启用" : "禁用")")
            }
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)🎉 RootContainer 初始化完成")
        }
    }

    // MARK: - Chat Plugin Wiring

    private func reloadChatPluginContributions() {
        guard let chatService = lumiCore.chatService as? ChatService else { return }

        if Self.verbose {
            Self.logger.info("\(Self.t)重载聊天插件贡献")
        }

        // 构造 plugin context（LumiCore 会自动注入 chatService / toolService 等基础服务）
        let context = lumiCore.makePluginContext(
            activeSectionID: "chat.core",
            activeSectionTitle: "Chat Core"
        )

        // 委托 LumiCore 完成工具注册 + ChatService 注入（App 层不接触任何 ToolService 细节）。
        // 工具名称唯一性已在 boot 阶段校验，此处直接注册。
        lumiCore.bootstrapToolContributions(provider: pluginService, context: context, builtInTools: ChatService.builtInTools)

        // 注册其他贡献
        let providers = pluginService.llmProviders(context: context)
        chatService.registerProviders(providers)
        chatService.registerMiddlewares(pluginService.sendMiddlewares(context: context))
        chatService.registerMessageRenderers(pluginService.messageRenderers(context: context))

        let subAgentCount = pluginService.subAgents(context: context).count

        NotificationCenter.default.post(
            name: .lumiLLMProvidersDidChange,
            object: nil,
            userInfo: nil
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ 聊天插件贡献重载完成: \(providers.count) 个 LLM Provider, \(subAgentCount) 个 SubAgent")
        }
    }
}
