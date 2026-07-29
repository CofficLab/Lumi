import Foundation
import LumiUI

// MARK: - Service Accessors

extension LumiKernelContainer {
    /// Storage service
    public var storage: (any StorageProviding)? {
        resolveService(StorageProviding.self)
    }

    /// Project management service
    public var project: (any ProjectProviding)? {
        resolveService(ProjectProviding.self)
    }

    /// Layout service
    public var layoutManager: (any LayoutProviding)? {
        resolveService(LayoutProviding.self)
    }

    /// Command menu service
    public var command: (any CommandProviding)? {
        resolveService(CommandProviding.self)
    }

    /// Shared UI service
    public var uiManager: (any UIManaging)? {
        resolveService(UIManaging.self)
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

    /// Message management service
    public var messageManager: (any MessageManaging)? {
        resolveService(MessageManaging.self)
    }

    /// Editor service
    public var editorProvider: (any EditorProviding)? {
        resolveService(EditorProviding.self)
    }

    /// File-tree/editor coordination service
    ///
    /// 文件树与编辑器的协同能力(高亮、打开/关闭/迁移 session、加入对话等)。
    /// 由编辑器插件注册,文件树等 UI 组件消费。
    public var fileTreeEditorCoordination: (any FileTreeEditorCoordination)? {
        resolveService(FileTreeEditorCoordination.self)
    }

    /// Editor tab-strip coordination service
    ///
    /// 标签栏与编辑器的协同能力(标签列表、激活/关闭/重排/置顶等)。
    /// 由编辑器插件注册,标签栏等 UI 组件消费。
    public var editorTabStripCoordination: (any EditorTabStripCoordination)? {
        resolveService(EditorTabStripCoordination.self)
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
}
