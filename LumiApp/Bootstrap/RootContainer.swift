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

    /// 安全获取 ChatService，类型不匹配时提供清晰的错误信息。
    static var checkedChatService: ChatService {
        guard let service = LumiCore.chatService as? ChatService else {
            fatalError("LumiCore.chatService 必须是 ChatService 类型。当前类型: \(String(describing: type(of: LumiCore.chatService)))。请确保 LumiCore.setupChatBootstrap 已正确调用。")
        }
        return service
    }

    static let shared: RootContainer = {
        do {
            return try RootContainer()
        } catch {
            RootContainer.logger.error("🗂️启动失败: \(error.localizedDescription)")
            let container = RootContainer(error: error)
            return container
        }
    }()

    @Published var initializationError: Error?

    let lumiCoreService: LumiCoreService
    let pluginService: PluginService
    let editorCoreService: EditorCoreService
    let chatSectionCoordinator: ChatSectionCoordinator
    let lumiUIService: LumiUIService
    let menuBarService: MenuBarService

    /// Normal throwing initializer
    private init() throws {
        // 启动早期同步恢复布局状态，确保首帧渲染前 activeViewContainerID 等已是持久化值。
        // 必须早于 AppLayoutView.onAppear：否则 onAppear 会先把默认 containers[0] 写入
        // activeViewContainerID 并经 LayoutEventListener 落盘，覆盖磁盘里的旧选择。
        // 此时 LayoutEventListener 尚未实例化（首帧才建），restore 写入发出的通知无人接收，安全。
        // 幂等：后续 PluginService.init → .appDidLaunch 会再调一次 restore，为 no-op。
        LumiPluginRegistry.restoreLayoutEarly()

        self.pluginService = PluginService()

        // Editor 工厂闭包捕获 pluginService；具体类型 EditorCoreService 已通过 LumiCore.boot
        // 内部 bootstrapEditor 同时注册到 LumiCore 服务表（抽象 + 具体）。
        // 注意：EditorCoreService 依赖 PluginService（启用态过滤），故必须先构造 pluginService。
        let editorFactory: LumiCore.EditorBootstrapFactory<EditorCoreService> = { provider in
            guard let pluginService = provider as? PluginService else {
                fatalError("Editor factory 收到的 provider 不是 PluginService")
            }
            return EditorCoreService(
                pluginService: pluginService,
                persistenceRootURL: { AppConfig.getDBFolderURL() },
                recentProjects: { [] }
            )
        }

        self.lumiCoreService = try LumiCoreService(
            provider: pluginService,
            editorFactory: editorFactory
        )

        // 通过服务表解析具体类型 EditorCoreService（LumiCore.boot 已在内部注册）。
        guard let editorService = LumiCore.resolveService(EditorCoreService.self) else {
            fatalError("LumiCore 服务表中未找到 EditorCoreService，请确认 LumiCoreService.init 的 editorFactory 已正确传递。")
        }
        self.editorCoreService = editorService

        self.chatSectionCoordinator = ChatSectionCoordinator(
            chatService: Self.checkedChatService,
            databaseDirectory: lumiCoreService.coreDatabaseDirectory
        )

        self.lumiUIService = LumiUIService(pluginService: pluginService)
        self.menuBarService = MenuBarService(pluginService: pluginService)

        // 注册核心服务到 LumiCore，供 makePluginContext 自动注入
        // （注意：EditorCoreService / AbstractEditorServicing 已在 LumiCore.boot 中注册，无需重复）
        LumiCore.registerService(LumiCoreService.self, lumiCoreService)
        LumiCore.registerService(ChatSectionCoordinator.self, chatSectionCoordinator)
        LumiCore.registerService(LumiBottomPanelLayoutPresenting.self, LumiCore.layoutState ?? LumiLayoutState())
        LumiCore.registerService(LumiThemeServicing.self, lumiUIService)
        LumiCore.registerService((any LumiLLMProviderSettingsContributing).self, pluginService)

        self.lumiUIService.onThemesDidChange = { [weak self] in
            self?.editorCoreService.syncAppSyntaxThemes()
        }
        LumiUIThemeRegistry.shared.onSystemAppearanceDidChange = { [weak self] in
            self?.editorCoreService.syncAppSyntaxThemes()
        }

        // 异步触发 UpdateService 的网络探测与延迟初始化，不阻塞主线程。
        // setupFeedURLIfNeeded 内部用 Task.detached 把网络请求放到后台线程，
        // 只有 Sparkle 必须在主线程的两步操作才会 hop 回 MainActor。
        UpdateService.shared.setupFeedURLIfNeeded()

        // 初始化聊天插件贡献（注册工具、LLM Provider 等）。
        // 注意：工具名称唯一性已在 LumiCore.boot() 阶段校验，此处不再抛出异常。
        reloadChatPluginContributions()


        // 初始化插件启用状态跟踪
        self.pluginService.initializePluginStates()
        self.pluginService.onEnabledPluginsChanged = { [weak self] in
            guard let self else { return }
            if Self.verbose {
                Self.logger.info("\(Self.t)插件启用状态变化，刷新相关服务")
            }
            // 运行期插件状态变更时重新注册工具贡献。
            // 工具名称唯一性已在 boot 阶段校验，此处不会抛出异常。
            self.reloadChatPluginContributions()
            self.lumiUIService.reloadThemes(from: self.pluginService)
            self.menuBarService.refresh()
            self.editorCoreService.reinstallExtensions()
        }

        // 连接插件生命周期回调，处理启用/禁用时的资源清理
        self.pluginService.onPluginLifecycleChange = { [weak self] (plugin, enabled) in
            guard let self else { return }
            if Self.verbose {
                Self.logger.info("\(Self.t)插件生命周期变化: \(plugin.info.id) -> \(enabled ? "启用" : "禁用")")
            }
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)🎉 RootContainer 初始化完成")
        }
    }

    /// Fallback initializer when bootstrap fails.
    /// Creates a minimal container that just holds the error for CrashedView.
    private init(error: Error) {
        self.initializationError = error
        self.lumiCoreService = LumiCoreService.fallbackStub()
        self.pluginService = PluginService()
        self.lumiUIService = LumiUIService(pluginService: PluginService())
        self.menuBarService = MenuBarService(pluginService: PluginService())

        self.editorCoreService = EditorCoreService(
                pluginService: self.pluginService,
                persistenceRootURL: { AppConfig.getDBFolderURL() },
                recentProjects: { [] }
            )

        guard let chatService = LumiCore.chatService as? ChatService else {
            Self.logger.error("LumiCore.chatService type mismatch in fallback container")
            fatalError("LumiCore.chatService must be ChatService in fallback container")
        }
        self.chatSectionCoordinator = ChatSectionCoordinator(
            chatService: chatService,
            databaseDirectory: URL(fileURLWithPath: NSTemporaryDirectory())
        )
    }

    // MARK: - Chat Plugin Wiring

    private func reloadChatPluginContributions() {
        guard let chatService = LumiCore.chatService as? ChatService else { return }

        if Self.verbose {
            Self.logger.info("\(Self.t)重载聊天插件贡献")
        }

        // 构造 plugin context（LumiCore 会自动注入 chatService / toolService 等基础服务）
        let context = LumiCore.makePluginContext(
            activeSectionID: "chat.core",
            activeSectionTitle: "Chat Core"
        )

        // 委托 LumiCore 完成工具注册 + ChatService 注入（App 层不接触任何 ToolService 细节）。
        // 工具名称唯一性已在 boot 阶段校验，此处直接注册。
        LumiCore.bootstrapToolContributions(provider: pluginService, context: context)

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
