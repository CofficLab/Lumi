import KernelCore
import KitLLM
import ProviderActivityBar
import ProviderAgentLoop
import ProviderChatSection
import ProviderCommand
import ProviderConversation
import ProviderContentView
import ProviderDocsView
import ProviderLifecycleHooks
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderLogo
import ProviderProject
import ProviderPromptSuggestion
import ProviderRailView
import ProviderRootView
import ProviderSettingView
import ProviderStorage
import ProviderTheme
import ProviderToolManager
import ProviderToolbar

/// AppIconDesigner 宿主需要的 Provider 装配契约。
@MainActor
public protocol ProviderFactory {
    func makeStorageProvider() -> any StorageProviding
    func makeThemeProvider() -> any ThemeProviding
    func makeContentViewProvider() -> any ContentViewProviding
    func makeConversationProvider() -> any ConversationManaging
    func makeMessageProvider() -> any MessageManaging
    func makeLLMProvider() -> any SuperLLMProvider
    func makeLLMManagerProvider() -> any LLMManaging
    func makeMessageStreamingProvider() -> any MessageStreamingProviding
    func makeLifecycleHooksProvider() -> any LifecycleHooksProviding
    func makeAgentLoopProvider(
        messages: any MessageManaging,
        llmManager: any LLMManaging,
        toolManager: any ToolManagerProviding,
        streaming: any MessageStreamingProviding,
        conversations: any ConversationManaging
    ) -> any AgentLoopProviding
    func makeDocsViewProvider() -> any DocsViewProviding
    func makeLogoProvider() -> any LogoProviding
    func makeProjectProvider() -> any ProjectProviding
    func makeChatSectionProvider() -> any ChatSectionProviding
    func makeToolManagerProvider() -> any ToolManagerProviding
    func makePromptSuggestionProvider() -> any PromptSuggestionProviding
    func makeToolbarProvider() -> any ToolbarProviding
    func makeRootViewProvider() -> any RootViewProviding
    func makeActivityBarProvider() -> any ActivityBarProviding
    func makeRailViewProvider() -> any RailViewProviding
    func makeSettingViewProvider() -> any SettingViewProviding
    func makeCommandProvider() -> any CommandProviding
    func registerProviders(into kernel: KernelCoreContainer) throws
}
