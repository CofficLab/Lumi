import Foundation
import LumiChatKit
import LumiCoreKit
import os
import SuperLogKit

/// LumiCore 的启动编排器：在 App 层把 LumiCore 实例创建出来、完成 boot、
/// 并把强类型的核心服务（`ChatService` / `EditorCoreService`）暴露给 RootContainer。
///
/// 这里承担的启动期编排（而非放在 RootContainer）是因为：
/// - `dataRootDirectory` 的物化、`editorFactory` 闭包、`configure(lumiCore:)` 回填等
///   都是 LumiCore 自己的启动细节，RootContainer 不应感知。
/// - `ChatService.applyPluginContributions` 需要在 boot 完成后立刻调用一次，
///   且运行期插件启用状态变化时重应用——而 `ChatService` 在 LumiChatKit 不能
///   反向依赖 `LumiPluginRegistry`，所以由本类（App 层）代为订阅广播触发。
@MainActor
final class LumiCoreService: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "service.lumi-core")
    nonisolated static let emoji = "⚙️"
    nonisolated static let verbose = false

    let lumiCore: LumiCore
    let dataRootDirectory: URL
    let coreDatabaseDirectory: URL

    /// boot 后从 `lumiCore.chatService` 强转并缓存的具体 `ChatService`。
    /// 替代 RootContainer 旧的 `checkedChatService(_:)` 静态强转——本类是唯一知道
    /// 「工厂创建的就是 ChatService」的地方（见 `setupChatService` 闭包），天然有资格 cast。
    let chatService: ChatService

    /// boot 后从服务表 resolve 的具体 `EditorCoreService`。
    /// 替代 RootContainer 旧的 `resolveService(EditorCoreService.self)` + fatalError 兜底。
    let editorCoreService: EditorCoreService

    /// 工具/子 Agent/Chat 贡献源（App 层的 PluginService）。保留引用以便运行期
    /// 插件启用状态变化时重新应用 Chat 维度贡献 + 重编排工具贡献。
    private let provider: any LumiAgentToolProviding

    /// 保留 pluginService 强类型引用：重应用 Chat 贡献时需要它的 `toolExecutionHook`。
    private let pluginService: PluginService

    /// NotificationCenter 观察者 token，用于 deinit 移除。
    private var pluginsChangedObserver: NSObjectProtocol?

    init(provider: PluginService) throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)初始化 LumiCoreService")
        }

        let dataRootDirectory = StorageService.makeDataRootDirectory()
        self.dataRootDirectory = dataRootDirectory
        self.coreDatabaseDirectory = StorageService.makeCoreDatabaseDirectory(in: dataRootDirectory)
        self.provider = provider
        self.pluginService = provider

        // 创建 LumiCore 实例
        let lumiCore = LumiCore()
        self.lumiCore = lumiCore

        // 设置 ChatService 工厂，boot() 时自动创建并注册
        lumiCore.setupChatService { [weak lumiCore] databaseDirectory in
            ChatService(configuration: .coreDatabase(directory: databaseDirectory), lumiCore: lumiCore)
        }

        // Editor 工厂：内化原先由 RootContainer 传入的闭包。EditorCoreService 在创建时
        // 拿不到 lumiCore（boot 还在进行），boot 完成后由本类调 configure 回填。
        let editorFactory: LumiCore.EditorBootstrapFactory<EditorCoreService> = { factoryProvider in
            guard let pluginService = factoryProvider as? PluginService else {
                fatalError("Editor factory 收到的 provider 不是 PluginService")
            }
            return EditorCoreService(
                pluginService: pluginService,
                recentProjects: { [] }
            )
        }

        try lumiCore.boot(
            dataRootDirectory: dataRootDirectory,
            provider: provider,
            builtInTools: ChatService.builtInTools,
            editorFactory: editorFactory
        )

        if Self.verbose {
            Self.logger.info("\(Self.t)数据根目录: \(dataRootDirectory.path)")
            Self.logger.info("\(Self.t)核心数据库目录: \(self.coreDatabaseDirectory.path)")
        }

        // 把自己注册为"当前活跃"的 LumiCore,让无法接收 LumiPluginContext 的静态
        // 单例(Plugin 的 LocalStore 等)能拿到存储路径。两个别名(MainActor 上下文用
        // `LumiCore.current`,非 MainActor 上下文用模块级 `currentLumiCore`)指向同一份
        // 引用,保持单一事实源。
        //
        // `currentLumiCoreDataRootDirectory` 是 `lumiCore.dataRootDirectory` 的 nonisolated
        // 镜像：plugin 侧 `static let shared = ...` 单例 init 经常发生在非 MainActor 上下文，
        // 直接读协议 `dataRootDirectory` 会撞 MainActor 隔离。镜像让 plugin 不用关心这点。
        LumiCore.current = lumiCore
        currentLumiCore = lumiCore
        currentLumiCoreDataRootDirectory = lumiCore.dataRootDirectory

        // —— 暴露强类型属性（吸收 RootContainer 旧的 checkedChatService 强转）——
        guard let chatService = lumiCore.chatService as? ChatService else {
            fatalError("LumiCore.chatService 必须是 ChatService。实际类型: \(String(describing: type(of: lumiCore.chatService)))")
        }
        self.chatService = chatService

        guard let editorCoreService = lumiCore.resolveService(EditorCoreService.self) else {
            fatalError("LumiCore 服务表中未找到 EditorCoreService，请确认 editorFactory 已正确传递。")
        }
        self.editorCoreService = editorCoreService

        // EditorCoreService 在 editorFactory 闭包里被创建时拿不到 lumiCore,
        // 这里通过 configure 补上,让它能读 projectState + 切换 persistence URL。
        editorCoreService.configure(lumiCore: lumiCore)

        // —— 把自己注册进服务表（吸收 RootContainer 的 registerService(LumiCoreService.self)）——
        lumiCore.registerService(LumiCoreService.self, self)
        // 把 PluginService 注册为 LLM Provider 设置贡献源,供 makePluginContext 自动注入
        // 到 LumiPluginContext（吸收 RootContainer 旧的 registerService((any LumiLLMProviderSettingsContributing).self)）。
        lumiCore.registerService((any LumiLLMProviderSettingsContributing).self, pluginService)

        // —— 应用 Chat 维度插件贡献（吸收 RootContainer 启动期的 applyPluginContributions）——
        applyChatPluginContributions()

        // —— 编排工具贡献：把插件工具 / 内置工具 / 子 Agent 工具注册进 ToolService ——
        // LLM Provider / 中间件 / 渲染器等 Chat 维度的贡献由 applyChatPluginContributions
        // 处理。工具名唯一性已在 boot 阶段校验,此处直接注册。
        bootstrapToolContributions()

        // —— 订阅运行期插件启用状态变化 ——
        // ChatService 在 LumiChatKit 不能 import LumiPluginRegistry,因此由本类
        // (App 层) 代为订阅,重应用 Chat 贡献 + 重编排工具贡献。其他 UI 服务
        // (LumiUI / MenuBar / Editor) 各自直接订阅同一 Notification 处理自己的刷新。
        pluginsChangedObserver = NotificationCenter.default.onLumiEnabledPluginsDidChange { [weak self] in
            guard let self else { return }
            if Self.verbose {
                Self.logger.info("\(Self.t)插件启用状态变化，重新应用贡献")
            }
            self.applyChatPluginContributions()
            self.bootstrapToolContributions()
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ LumiCoreService 初始化完成")
        }
    }

    deinit {
        if let pluginsChangedObserver {
            NotificationCenter.default.removeObserver(pluginsChangedObserver)
        }
    }

    /// 应用 Chat 维度插件贡献（providers / middlewares / renderers / turn hook + tool execution hook）。
    /// 启动期调用一次,运行期插件状态变化时由 Notification 回调再次调用。
    private func applyChatPluginContributions() {
        chatService.applyPluginContributions(
            from: pluginService,
            toolExecutionHook: pluginService.toolExecutionHook
        )
    }

    /// 重新编排工具贡献。让新启用插件贡献的工具 / 子 Agent 进入 ToolService。
    func bootstrapToolContributions() {
        let context = lumiCore.makePluginContext(
            activeSectionID: "chat.core",
            activeSectionTitle: "Chat Core"
        )
        lumiCore.bootstrapToolContributions(
            provider: provider,
            context: context,
            builtInTools: ChatService.builtInTools
        )
    }
}
