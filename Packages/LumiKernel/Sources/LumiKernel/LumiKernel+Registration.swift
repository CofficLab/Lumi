import Foundation
import LumiUI

// MARK: - Service Registration

extension LumiKernelContainer {
    /// Register storage service
    public func registerStorage(_ storage: any StorageProviding) {
        registerService(StorageProviding.self, storage)
    }

    /// Register project management service
    public func registerProject(_ project: any ProjectProviding) {
        registerService(ProjectProviding.self, project)
    }

    /// Register layout service
    public func registerLayout(_ layout: any LayoutProviding) {
        registerService(LayoutProviding.self, layout)
    }

    /// Register command service
    public func registerCommandService(_ command: any CommandProviding) {
        registerService(CommandProviding.self, command)
    }

    /// Register shared UI service
    public func registerSharedUIService(_ sharedUI: any UIManaging) {
        registerService(UIManaging.self, sharedUI)
    }

    /// Register message send service
    public func registerMessageSend(_ messageSend: any MessageSending) {
        registerService(MessageSending.self, messageSend)
    }

    /// Register conversation input service
    public func registerConversationInputService(_ conversationInput: any ConversationInputProviding) {
        registerService(ConversationInputProviding.self, conversationInput)
    }

    /// Register conversation managing service
    public func registerConversations(_ conversations: any ConversationManaging) {
        registerService(ConversationManaging.self, conversations)
    }

    /// Register message managing service
    public func registerMessageManager(_ messageManager: any MessageManaging) {
        registerService(MessageManaging.self, messageManager)
    }

    /// Register editor service
    public func registerEditor(_ editor: any EditorProviding) {
        registerService(EditorProviding.self, editor)
    }

    /// Register file-tree/editor coordination service
    ///
    /// 注册文件树与编辑器协同能力(通常由编辑器插件以 `EditorContext` 实现)。
    /// 文件树等 UI 组件通过 `kernel.resolveService(FileTreeEditorCoordination.self)` 取用。
    public func registerFileTreeEditorCoordination(_ coordination: any FileTreeEditorCoordination) {
        registerService(FileTreeEditorCoordination.self, coordination)
    }

    /// Register editor tab-strip coordination service
    ///
    /// 注册标签栏与编辑器协同能力(通常由编辑器插件以 `EditorContext` 实现)。
    /// 标签栏等 UI 组件通过 `kernel.resolveService(EditorTabStripCoordination.self)` 取用。
    public func registerEditorTabStripCoordination(_ coordination: any EditorTabStripCoordination) {
        registerService(EditorTabStripCoordination.self, coordination)
    }

    /// Register agent tool service
    public func registerToolManagerService(_ toolManager: any ToolManaging) {
        registerService(ToolManaging.self, toolManager)
    }

    /// Register LLM Provider service
    public func registerLLMProviderService(_ llmProvider: any LLMProviderManaging) {
        registerService(LLMProviderManaging.self, llmProvider)
    }

    /// Register agent turn runner service
    public func registerAgentTurnRunnerService(_ agentTurnRunner: any AgentTurnRunning) {
        registerService(AgentTurnRunning.self, agentTurnRunner)
    }

    /// Register settings service
    public func registerSettingsService(_ settings: any SettingsProviding) {
        registerService(SettingsProviding.self, settings)
    }

    /// Register logo service
    public func registerLogoService(_ logo: any LogoProviding) {
        registerService(LogoProviding.self, logo)
    }

    /// Register theme service
    public func registerThemeService(_ theme: any UIThemeProviding) {
        registerService(UIThemeProviding.self, theme)
    }

    /// Register onboarding service
    public func registerOnboardingService(_ onboarding: any OnboardingProviding) {
        registerService(OnboardingProviding.self, onboarding)
    }

    /// Register message renderer management service
    public func registerMessageRendererManagerService(_ manager: any MessageRendering) {
        registerService(MessageRendering.self, manager)
    }

    /// Register legacy data service (v4 → v5 migration, read-only)
    ///
    /// 可选服务:仅在 v4→v5 迁移窗口期注册,迁移完成后可整体移除。
    public func registerLegacyDataService(_ legacyData: any LegacyDataProviding) {
        registerService(LegacyDataProviding.self, legacyData)
    }
}
