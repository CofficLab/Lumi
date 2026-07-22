import Foundation
import LumiUI

// MARK: - Service Registration

extension LumiKernelContainer {
    /// Register LumiCore service
    public func registerLumiCore(_ core: any LumiCoreProviding) {
        registerService(LumiCoreProviding.self, core)
    }

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

    /// Register menu bar service
    public func registerMenuBarService(_ menuBar: any MenuBarProviding) {
        registerService(MenuBarProviding.self, menuBar)
    }

    /// Register title toolbar service
    public func registerTitleToolbarService(_ titleToolbar: any TitleToolbarProviding) {
        registerService(TitleToolbarProviding.self, titleToolbar)
    }

    /// Register send middleware service
    public func registerSendMiddlewareService(_ sendMiddleware: any SendMiddlewareProviding) {
        registerService(SendMiddlewareProviding.self, sendMiddleware)
    }

    /// Register chat service
    public func registerChat(_ chat: any ChatServiceProviding) {
        registerService(ChatServiceProviding.self, chat)
    }

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

    /// Register chat section service
    public func registerChatSectionService(_ chatSection: any ChatSectionProviding) {
        registerService(ChatSectionProviding.self, chatSection)
    }

    /// Register editor service
    public func registerEditor(_ editor: any EditorServiceProviding) {
        registerService(EditorServiceProviding.self, editor)
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

    /// Register Chat contribution service
    public func registerChatContributionService(_ chatContribution: any ChatContributionProviding) {
        registerService(ChatContributionProviding.self, chatContribution)
    }

    /// Register panel service
    public func registerPanelService(_ panel: any PanelProviding) {
        registerService(PanelProviding.self, panel)
    }

    /// Register status bar service
    public func registerStatusBarService(_ statusBar: any StatusBarProviding) {
        registerService(StatusBarProviding.self, statusBar)
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
    public func registerMessageRendererManagerService(_ manager: any MessageRendererManaging) {
        registerService(MessageRendererManaging.self, manager)
    }

    /// Register workspace state service
    public func registerWorkspaceStateService(_ state: any WorkspaceStateProviding) {
        registerService(WorkspaceStateProviding.self, state)
    }
}
