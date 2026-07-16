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

    /// 初始化所有服务并启动 LumiCore。
    ///
    /// 职责严格限定为：按依赖顺序实例化各服务 → 注册进 LumiCore 服务表 → 触发启动。
    /// 不再包含插件贡献注册算法、主题/更新副作用、运行期事件处理逻辑——这些已各归其位：
    /// - Chat 维度贡献（providers/middlewares/renderers/hook）→ `ChatService.applyPluginContributions`
    /// - 工具维度贡献 → `LumiCoreService.bootstrapToolContributions`
    /// - 主题同步 → `LumiUIService.connectEditorThemeSync` / `EditorCoreService` 自订阅读系统外观
    /// - 更新 feed 探测 → `MacAgent.applicationDidFinishLaunching`
    /// - 运行期插件状态变化 → `wirePluginStateObservers()` 仅做一行转发
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

        // 启动 LumiCore：内部创建 ChatService、注册 EditorCoreService、编排工具贡献。
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

        // 注册进服务表
        lumiCore.registerService(LumiCoreService.self, lumiCoreService)
        lumiCore.registerService(ChatSectionCoordinator.self, chatSectionCoordinator)
        lumiCore.registerService(LumiThemeServicing.self, lumiUIService)
        lumiCore.registerService((any LumiLLMProviderSettingsContributing).self, pluginService)

        // —— 启动期接线（纯转发，不含业务算法）——
        // 主题变更 → 编辑器语法主题同步
        lumiUIService.connectEditorThemeSync(editorCoreService)
        // 应用 Chat 维度的插件贡献（providers/middlewares/renderers/turn hook + tool execution hook）
        Self.checkedChatService(lumiCore).applyPluginContributions(
            from: pluginService,
            toolExecutionHook: makeToolExecutionHook()
        )
        // 运行期插件 enable/disable 协调
        wirePluginStateObservers()

        if Self.verbose {
            Self.logger.info("\(Self.t)🎉 RootContainer 初始化完成")
        }
    }

    // MARK: - Plugin State Wiring

    /// 构造工具执行钩子闭包：把工具执行结果转发给插件注册表，由插件决定是否暂停
    /// Agent 循环（如 ask_user 等待用户回答）。
    ///
    /// 这是 App 层对 `LumiPluginRegistry` 的反向桥接——`LumiChatKit` 不直接依赖插件注册表，
    /// 经此闭包注入。见 `ChatService.toolExecutionHook` 字段注释。
    private func makeToolExecutionHook() -> (String, String, UUID) async -> Bool {
        { toolName, result, conversationID in
            await LumiPluginRegistry.dispatchToolExecution(
                toolName: toolName,
                result: result,
                conversationID: conversationID
            )
        }
    }

    /// 订阅插件启用状态变化，把"插件集合变了"这个跨服务协调信号分发给各服务。
    ///
    /// 这里只做一行一行的转发：通知每个关心的服务重新加载自己的那部分。
    /// `onEnabledPluginsChanged` 是 `LumiPluginRegistry` 的单一静态闭包槽，
    /// 会覆盖 `PluginService.init` 里设置的纯 UI 刷新回调，因此第一行手动补发
    /// `objectWillChange` 以保持 SwiftUI 刷新。
    private func wirePluginStateObservers() {
        LumiPluginRegistry.onEnabledPluginsChanged = { [weak self] in
            guard let self else { return }
            if Self.verbose {
                Self.logger.info("\(Self.t)插件启用状态变化，刷新相关服务")
            }
            // 1. 补回 PluginService.init 被覆盖的 UI 刷新职责
            pluginService.objectWillChange.send()
            // 2. 重新应用 Chat 维度贡献（providers/middlewares/renderers/hook）
            Self.checkedChatService(lumiCore).applyPluginContributions(
                from: pluginService,
                toolExecutionHook: makeToolExecutionHook()
            )
            // 3. 重新编排工具贡献（插件工具 / 子 Agent 工具）
            lumiCoreService.bootstrapToolContributions()
            // 4. 各 UI/编辑器服务自刷新
            lumiUIService.reloadThemes(from: pluginService)
            menuBarService.refresh()
            editorCoreService.reinstallExtensions()
        }
    }
}
