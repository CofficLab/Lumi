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

    /// View container service
    public var viewContainer: (any ViewContainerProviding)? {
        resolveService(ViewContainerProviding.self)
    }

    /// Command menu service
    public var command: (any CommandProviding)? {
        resolveService(CommandProviding.self)
    }

    /// Shared UI service
    public var sharedUI: (any SharedUIProviding)? {
        resolveService(SharedUIProviding.self)
    }

    /// Send middleware service (removed: now handled via LumiPlugin.willSendToLLM hook)

    /// Message send service (user input → persist + dispatch)
    public var messageSender: (any MessageSending)? {
        resolveService(MessageSending.self)
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

    /// Agent tool service
    public var toolManager: (any ToolManaging)? {
        resolveService(ToolManaging.self)
    }

    /// LLM Provider service
    public var llmProvider: (any LLMProviderManaging)? {
        resolveService(LLMProviderManaging.self)
    }

    /// Agent turn runner service (executes LLM loop including tool calls)
    public var agentTurnRunner: (any AgentTurnRunning)? {
        resolveService(AgentTurnRunning.self)
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
    public var theme: (any LumiThemeServicing)? {
        resolveService(LumiThemeServicing.self)
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
}
