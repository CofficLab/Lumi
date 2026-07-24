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

    /// Register view container service
    public func registerViewContainerService(_ service: any ViewContainerProviding) {
        registerService(ViewContainerProviding.self, service)
    }

    /// Register command service
    public func registerCommandService(_ command: any CommandProviding) {
        registerService(CommandProviding.self, command)
    }

    /// Register shared UI service
    public func registerSharedUIService(_ sharedUI: any SharedUIProviding) {
        registerService(SharedUIProviding.self, sharedUI)
    }

    /// Register send middleware service (removed: now handled via LumiPlugin.willSendToLLM hook)

    /// Register message send service
    public func registerMessageSend(_ messageSend: any MessageSending) {
        registerService(MessageSending.self, messageSend)
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
    public func registerThemeService(_ theme: any LumiThemeServicing) {
        registerService(LumiThemeServicing.self, theme)
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
