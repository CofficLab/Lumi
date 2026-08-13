import Foundation
import LumiUI

// MARK: - Service Registration

extension KernelLumiContainer {
    /// Register storage service
    public func registerStorage(_ storage: any StorageProviding) throws {
        try registerService(StorageProviding.self, storage)
    }

    /// Register idle-time activity service.
    public func registerIdleTime(_ idleTime: any IdleTimeProviding) throws {
        try registerService(IdleTimeProviding.self, idleTime)
    }

    /// Register project management service
    public func registerProject(_ project: any ProjectProviding) throws {
        try registerService(ProjectProviding.self, project)
    }

    /// Register workspace service (layout geometry + plugin UI contributions)
    public func registerWorkspace(_ workspace: any WorkspaceProviding) throws {
        try registerService(WorkspaceProviding.self, workspace)
    }

    /// Register command service
    public func registerCommandService(_ command: any CommandProviding) throws {
        try registerService(CommandProviding.self, command)
    }

    /// Register message send service
    public func registerMessageSend(_ messageSend: any MessageSending) throws {
        try registerService(MessageSending.self, messageSend)
    }

    /// Register conversation input service.
    ///
    /// Input text, IME composition state, cursor position and auto-growing
    /// height are high-frequency UI state. They must be observed by the input
    /// views directly instead of being forwarded through the Kernel-wide
    /// objectWillChange publisher.
    ///
    /// Consumers that render input state must observe the concrete input
    /// service directly. This keeps keystrokes and IME composition local to
    /// the input subtree instead of invalidating unrelated Kernel observers.
    public func registerConversationInputService(_ conversationInput: any ConversationInputProviding) throws {
        try registerService(
            ConversationInputProviding.self,
            conversationInput,
            forwardsObjectWillChange: false
        )
    }

    /// Register conversation managing service
    public func registerConversations(_ conversations: any ConversationManaging) throws {
        try registerService(ConversationManaging.self, conversations)
    }

    /// Register message managing service
    public func registerMessageManager(_ messageManager: any MessageManaging) throws {
        try registerService(MessageManaging.self, messageManager)
    }

    /// Register message streaming service (runner writes streaming tokens, UI reads them).
    ///
    /// 可选增强服务：缺失时 UI 优雅降级为不显示流式临时行（最终落库消息仍正常显示）。
    ///
    /// **不转发 objectWillChange**：流式期间该服务高频变更（每个 token 一次），
    /// 经 kernel 全局广播会拖慢整个 app。消费方改用 `ObservableMessageStreamingBox`
    /// 精确订阅。
    public func registerMessageStreaming(_ streaming: any MessageStreaming) throws {
        try registerService(MessageStreaming.self, streaming, forwardsObjectWillChange: false)
    }

    /// Register editor service
    public func registerEditor(_ editor: any EditorProviding) throws {
        try registerService(EditorProviding.self, editor)
    }

    /// Register file-tree/editor coordination service
    ///
    /// 注册文件树与编辑器协同能力(通常由编辑器插件以 `EditorContext` 实现)。
    /// 文件树等 UI 组件通过 `kernel.resolveService(FileTreeEditorCoordination.self)` 取用。
    public func registerFileTreeEditorCoordination(_ coordination: any FileTreeEditorCoordination) throws {
        try registerService(FileTreeEditorCoordination.self, coordination)
    }

    /// Register editor tab-strip coordination service
    ///
    /// 注册标签栏与编辑器协同能力(通常由编辑器插件以 `EditorContext` 实现)。
    /// 标签栏等 UI 组件通过 `kernel.resolveService(EditorTabStripCoordination.self)` 取用。
    public func registerEditorTabStripCoordination(_ coordination: any EditorTabStripCoordination) throws {
        try registerService(EditorTabStripCoordination.self, coordination)
    }

    /// Register agent tool service
    public func registerToolManagerService(_ toolManager: any ToolManaging) throws {
        try registerService(ToolManaging.self, toolManager)
    }

    /// Register LLM Provider service
    public func registerLLMProviderService(_ llmProvider: any LLMProviderManaging) throws {
        try registerService(LLMProviderManaging.self, llmProvider)
    }

    /// Register the agent turn manager service.
    public func registerAgentTurnManagerService(_ agentTurnManager: any AgentTurnManaging) throws {
        try registerService(AgentTurnManaging.self, agentTurnManager)
    }

    /// Register settings service
    public func registerSettingsService(_ settings: any SettingsProviding) throws {
        try registerService(SettingsProviding.self, settings)
    }

    /// Register logo service
    public func registerLogoService(_ logo: any LogoProviding) throws {
        try registerService(LogoProviding.self, logo)
    }

    /// Register theme service
    public func registerThemeService(_ theme: any UIThemeProviding) throws {
        try registerService(UIThemeProviding.self, theme)
    }

    /// Register onboarding service
    public func registerOnboardingService(_ onboarding: any OnboardingProviding) throws {
        try registerService(OnboardingProviding.self, onboarding)
    }

    /// Register prompt suggestion aggregation service.
    ///
    /// 内核在 `startup()` 中注册默认实现 `PromptSuggestionManager`；插件也可在
    /// `onBoot` 中调用此方法注册自定义实现以覆盖默认。
    public func registerPromptSuggestionService(_ service: any PromptSuggestionProviding) throws {
        try registerService(PromptSuggestionProviding.self, service)
    }

    /// Register message renderer management service
    public func registerMessageRendererManagerService(_ manager: any MessageRendering) throws {
        try registerService(MessageRendering.self, manager)
    }

    /// Register legacy data service (v4 → v5 migration, read-only)
    ///
    /// 可选服务:仅在 v4→v5 迁移窗口期注册,迁移完成后可整体移除。
    public func registerLegacyDataService(_ legacyData: any LegacyDataProviding) throws {
        try registerService(LegacyDataProviding.self, legacyData)
    }
}
