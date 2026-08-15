import Foundation
import LumiUI

// MARK: - Service Accessors

extension KernelLumiContainer {
    /// Storage service
    public var storage: (any StorageProviding)? {
        resolveService(StorageProviding.self)
    }

    /// Idle-time activity and rest-window service.
    public var idleTime: (any IdleTimeProviding)? {
        resolveService(IdleTimeProviding.self)
    }

    /// Project management service
    public var project: (any ProjectProviding)? {
        resolveService(ProjectProviding.self)
    }

    /// Workspace service (layout geometry + plugin UI contributions)
    ///
    /// 合并自原 LayoutProviding（布局状态机）与 UIManaging（插件 UI 贡献注册表）。
    /// 由 LayoutManager 实现。
    public var workspace: (any WorkspaceProviding)? {
        resolveService(WorkspaceProviding.self)
    }

    /// Command menu service
    public var command: (any CommandProviding)? {
        resolveService(CommandProviding.self)
    }

    /// Menu bar presentation service
    public var menuBarPresenter: (any MenuBarPresenting)? {
        resolveService(MenuBarPresenting.self)
    }

    /// Message send service (user input → persist + dispatch)
    public var messageSender: (any MessageSending)? {
        resolveService(MessageSending.self)
    }

    /// Conversation input service
    public var conversationInput: (any ConversationInputProviding)? {
        resolveService(ConversationInputProviding.self)
    }

    /// Conversation management service
    public var conversations: (any ConversationManaging)? {
        resolveService(ConversationManaging.self)
    }

    /// 同 `conversations`,作为 `ConversationManaging` 的简写访问器,
    /// 便于 UI 层按职责命名(管理对话设置,包括 verbosity 等)。
    public var conversationManager: (any ConversationManaging)? {
        resolveService(ConversationManaging.self)
    }

    /// Message management service
    public var messageManager: (any MessageManaging)? {
        resolveService(MessageManaging.self)
    }

    /// Message streaming service (current in-flight streaming assistant row).
    ///
    /// 由 runner 写入、UI 读取。可选服务，未注册时为 nil（UI 不显示流式临时行）。
    public var messageStreaming: (any MessageStreaming)? {
        resolveService(MessageStreaming.self)
    }

    /// Editor service
    public var editorProvider: (any EditorProviding)? {
        resolveService(EditorProviding.self)
    }

    /// Agent tool service
    public var toolManager: (any ToolManaging)? {
        resolveService(ToolManaging.self)
    }

    /// LLM Provider service
    public var llmProvider: (any LLMProviderManaging)? {
        resolveService(LLMProviderManaging.self)
    }

    /// Agent turn manager service (executes and manages the LLM loop including tool calls)
    public var agentTurnManager: (any AgentTurnManaging)? {
        resolveService(AgentTurnManaging.self)
    }

    /// Settings service
    public var settings: (any SettingsProviding)? {
        resolveService(SettingsProviding.self)
    }

    /// Logo service
    public var logo: (any LogoProviding)? {
        resolveService(LogoProviding.self)
    }

    /// Theme service
    public var theme: (any UIThemeProviding)? {
        resolveService(UIThemeProviding.self)
    }

    /// Onboarding service
    public var onboarding: (any OnboardingProviding)? {
        resolveService(OnboardingProviding.self)
    }

    /// Prompt suggestion aggregation service (chat starter prompts contributed by plugins).
    ///
    /// 内核提供默认实现 `PromptSuggestionManager`（在 `startup()` 中注册）。
    /// 消费方读取 `allPromptSuggestions` 即可拿到所有插件聚合后的提示词。
    public var promptSuggestions: (any PromptSuggestionProviding)? {
        resolveService(PromptSuggestionProviding.self)
    }

    /// Plugin control service (enable / disable plugins at runtime + persistence).
    ///
    /// 由 `PluginManagerPlugin` 注册实现 `PluginController`。消费方（如空态提示词视图）
    /// 可调用 `enablePlugin(id:)` 在点击禁用插件的提示词时「启用并发送」。
    public var pluginControl: (any PluginControlling)? {
        resolveService(PluginControlling.self)
    }

    /// Message renderer management service
    public var messageRendererManager: (any MessageRendering)? {
        resolveService(MessageRendering.self)
    }

    /// Legacy data service (v4 → v5 migration, read-only)
    ///
    /// 可选服务:未注册时返回 nil(全新安装或迁移窗口期之后)。
    /// 消费插件应 `guard let legacy = kernel.legacyData else { return }` 跳过迁移。
    public var legacyData: (any LegacyDataProviding)? {
        resolveService(LegacyDataProviding.self)
    }

    /// Network service (HTTP requests)
    ///
    /// 可选服务:未注册时返回 nil。
    /// 消费插件应 `guard let network = kernel.network else { return }` 处理网络功能不可用的情况。
    public var network: (any NetworkProviding)? {
        resolveService(NetworkProviding.self)
    }

    /// Toast 展示服务 (transient user-facing hints)
    ///
    /// 可选服务:未注册时返回 nil。
    /// 消费方应 `guard let toast = kernel.toast else { return }` 或使用
    /// 可选链静默跳过,保证在未提供 Toast 实现的精简宿主中 no-op。
    public var toast: (any ToastProviding)? {
        resolveService(ToastProviding.self)
    }

    /// Local web server service (inbound HTTP API for plugin-contributed routes).
    ///
    /// 可选服务:未注册时返回 nil。与 `network`(出站客户端)互补,本服务是入站
    /// 服务端,聚合插件通过 `LumiPlugin.webRoutes(kernel:)` 贡献的路由。
    /// 消费方应 `guard let webServer = kernel.webServer else { return }` 处理不可用情况。
    public var webServer: (any WebServerProviding)? {
        resolveService(WebServerProviding.self)
    }
}
