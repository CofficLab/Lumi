import LumiAppKit
import LumiCoreKit
import LumiPluginRegistry
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// App 的组合根（Composition Root）：唯一的启动入口。
///
/// 承担完整启动职责——创建 LumiCore、装配所有服务、注册、接线、运行期插件贡献协调。
/// 这里没有"LumiCore 启动器"中间层：所有启动细节（dataRoot 物化、工厂、configure 回填、
/// 贡献应用、Notification 订阅）都在本类的 init 内。
///
/// 职责分区：
/// - **创建**：按依赖顺序实例化 LumiCore + 6 个 App 层服务
/// - **接线**：cast 强类型服务、configure 回填、设置全局静态指针
/// - **注册**：把服务写进 LumiCore 服务表
/// - **运行期协调**：插件启用状态变化时，重应用 Chat 维度贡献 + 重编排工具贡献
///   （ChatService 在 LumiChatKit 不能 import LumiPluginRegistry，所以由本类代为订阅）
@MainActor
final class RootContainer: ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "bootstrap.root-container")
    nonisolated static let emoji = "🗂️"
    nonisolated static let verbose = false

    let lumiCore: LumiCore
    let pluginService: PluginService
    let chatService: ChatService
    let editorCoreService: EditorCoreService
    let chatSectionCoordinator: ChatSectionCoordinator
    let lumiUIService: LumiUIService
    let menuBarService: MenuBarService

    /// 工具/子 Agent/Chat 贡献源。保留引用以便运行期插件启用状态变化时
    /// 重新应用 Chat 维度贡献 + 重编排工具贡献。
    private let provider: any AgentToolProviding

    /// NotificationCenter 观察者 token，用于 deinit 移除。
    private var pluginsChangedObserver: NSObjectProtocol?

    init() throws {
        // —— 1. 创建 PluginService（无依赖，第一个 new）——
        let pluginService = PluginService()
        self.pluginService = pluginService
        self.provider = pluginService

        // —— 2. 物化数据根目录 ——
        let dataRootDirectory = try StorageService.makeDataRootDirectory()
        let coreDatabaseDirectory = try StorageService.makeCoreDatabaseDirectory(in: dataRootDirectory)

        // —— 3. Editor 工厂闭包 ——
        // 返回 EditorCoreService 实例。此时还不持有 lumiCore——LumiCore.init 会接收并存储
        // 返回值，但 `configure(lumiCore:)` 回填由本 init 在 LumiCore 创建完成后调用
        // （configure 是 EditorCoreService 的具体方法，不在 AbstractEditorServicing 协议里）。
        let editorFactory: @MainActor (any AgentToolProviding) throws -> any AbstractEditorServicing = { factoryProvider in
            guard let pluginService = factoryProvider as? PluginService else {
                throw LumiBootstrapError.editorProviderCastFailed
            }
            return EditorCoreService(
                pluginService: pluginService,
                recentProjects: { [] }
            )
        }

        // —— 4. 一次性创建 LumiCore ——
        // 内部完成 ProjectComponent / LayoutState / dataRoot 物化 / ChatService 创建
        // （留空 lumiCore）/ ToolService / EditorService 的全部绑定。
        // ChatService 的 lumiCore 引用留空，由下方 configure 回填
        // （Swift 两阶段初始化约束：创建 ChatService 时 self 不可 escape）。
        let lumiCore = try LumiCore(
            dataRootDirectory: dataRootDirectory,
            provider: provider,
            builtInTools: ChatService.builtInTools,
            chatServiceFactory: { databaseDirectory in
                try ChatService(configuration: .coreDatabase(directory: databaseDirectory))
            },
            editorFactory: editorFactory
        )
        self.lumiCore = lumiCore

        if Self.verbose {
            Self.logger.info("\(Self.t)数据根目录: \(dataRootDirectory.path)")
            Self.logger.info("\(Self.t)核心数据库目录: \(coreDatabaseDirectory.path)")
        }

        // —— 5. 设置全局静态指针 ——
        // LumiCore.current 供 FileLogPlugin 等没有 context 的 lifecycle 入口读取路径。
        // 各 plugin 的数据目录由它们各自的 bootstrapFromLumiCoreIfNeeded 注入
        // (走 LumiPluginContext.lumiCore,不再依赖 nonisolated 镜像)。
        LumiCore.current = lumiCore

        // —— 6. 暴露强类型 chatService + 回填 lumiCore 引用 ——
        guard let chatService = lumiCore.chatService as? ChatService else {
            throw LumiBootstrapError.chatServiceCastFailed(
                actual: String(describing: type(of: lumiCore.chatService))
            )
        }
        self.chatService = chatService
        chatService.configure(delegate: lumiCore)

        // —— 7. 暴露强类型 editorCoreService + configure 回填 ——
        guard let editorCoreService = lumiCore.editorService as? EditorCoreService else {
            throw LumiBootstrapError.editorServiceCastFailed(
                actual: String(describing: type(of: lumiCore.editorService))
            )
        }
        self.editorCoreService = editorCoreService
        editorCoreService.configure(lumiCore: lumiCore)
        // 把具体类型也注册进服务表（供需要 EditorCoreService 强类型的调用方解析）。
        lumiCore.registerService(EditorCoreService.self, editorCoreService)

        // —— 8. 创建其余 App 层服务 ——
        self.chatSectionCoordinator = ChatSectionCoordinator(
            chatService: chatService,
            databaseDirectory: coreDatabaseDirectory
        )
        self.lumiUIService = LumiUIService(
            pluginService: pluginService,
            lumiCore: lumiCore,
            editorCoreService: editorCoreService
        )
        self.menuBarService = MenuBarService(pluginService: pluginService, lumiCore: lumiCore)

        // —— 9. 注册服务进 LumiCore 服务表 ——
        lumiCore.registerService(ChatSectionCoordinator.self, chatSectionCoordinator)
        lumiCore.registerService(LumiThemeServicing.self, lumiUIService)
        lumiCore.registerService((any LumiLLMProviderSettingsContributing).self, pluginService)

        // —— 10. 应用 Chat 维度插件贡献 ——
        // LLM Provider / 中间件 / 渲染器等 Chat 维度贡献由 applyChatPluginContributions 处理。
        // 工具贡献（per-request）不再在启动期收集——每次发消息时由
        // AgentToolComponent.buildToolSet 按当前 context 动态构建，启动期零工具开销。
        applyChatPluginContributions()

        // —— 11. 订阅运行期插件启用状态变化 ——
        // ChatService 在 LumiChatKit 不能 import LumiPluginRegistry，因此由本类
        // （App 层）代为订阅，重应用 Chat 贡献 + 重编排工具贡献。
        // 其他 UI 服务（LumiUI / MenuBar / Editor）各自直接订阅同一 Notification。
        pluginsChangedObserver = NotificationCenter.default.onLumiEnabledPluginsDidChange { [weak self] in
            guard let self else { return }
            if Self.verbose {
                Self.logger.info("\(Self.t)插件启用状态变化，重新应用贡献")
            }
            // per-request 改造后工具集不再需要重建——下次发消息时 buildToolSet 自然
            // 反映最新的插件启用状态。这里只重应用 Chat 维度贡献（provider/middleware 等）。
            self.applyChatPluginContributions()
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)🎉 RootContainer 初始化完成")
        }
    }

    deinit {
        if let pluginsChangedObserver {
            NotificationCenter.default.removeObserver(pluginsChangedObserver)
        }
    }

    // MARK: - Plugin Contributions

    /// 应用 Chat 维度插件贡献（providers / middlewares / renderers / turn hook + tool execution hook）。
    /// 启动期调用一次，运行期插件状态变化时由 Notification 回调再次调用。
    private func applyChatPluginContributions() {
        chatService.applyPluginContributions(
            from: pluginService,
            toolExecutionHook: pluginService.toolExecutionHook
        )
    }

    /// 在所有插件 lifecycle（`.didRegister` + `.appDidLaunch`）完成后做最后的启动校验。
    ///
    /// 由 `WindowMain.initializeContainer` 在 `RootContainer()` 创建后显式 await。
    ///
    /// per-request 动态注入改造后，启动期**不再收集工具**——工具集完全由
    /// `AgentToolComponent.buildToolSet` 在每次发消息时按当前 context 构建。
    /// 因此本方法只负责：等待插件 lifecycle 完成 + 检查 lifecycle 失败。
    /// 工具相关的失败（软去重冲突、单插件 agentTools 抛错）改在发消息时软降级，
    /// 不再走启动期 CrashedView。
    ///
    /// - throws: 若 lifecycle 失败非空，抛出聚合错误，由 WindowMain 走 `CrashedView`。
    func bootstrapAfterPluginLifecycle() async throws {
        // 1. 等待所有插件 lifecycle 完成（原由 PluginService.init 的异步 Task 触发，
        //    现收敛到此处，保证 registerAll → appDidLaunch 的严格顺序）。
        // registerAll/appDidLaunch 内部已逐插件捕获 lifecycle 抛错，累积到 lifecycleFailures。
        await LumiPluginRegistry.registerAll()
        await LumiPluginRegistry.appDidLaunch()

        // 2. 只检查 lifecycle 失败。工具贡献失败已改为发消息时软降级，不在此阻断启动。
        let allFailures = LumiPluginRegistry.lifecycleFailures
        if !allFailures.isEmpty {
            throw LumiPluginContributionFailureAggregate(allFailures)
        }
    }
}
