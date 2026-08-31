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

/// AppIconDesigner 的最小 Provider 装配。
@MainActor
public struct DefaultProviderFactory: ProviderFactory {
    public init() {}

    public func makeStorageProvider() -> any StorageProviding { DefaultStorageProvider() }
    public func makeThemeProvider() -> any ThemeProviding { DefaultThemeProviding() }
    public func makeContentViewProvider() -> any ContentViewProviding { DefaultContentViewProviding() }
    public func makeConversationProvider() -> any ConversationManaging { DefaultConversationManager() }
    public func makeMessageProvider() -> any MessageManaging { DefaultMessageManager() }
    public func makeLLMProvider() -> any SuperLLMProvider { DefaultLLMProviding() }
    public func makeLLMManagerProvider() -> any LLMManaging { DefaultLLMManager() }
    public func makeMessageStreamingProvider() -> any MessageStreamingProviding {
        DefaultMessageStreamingProviding()
    }
    public func makeLifecycleHooksProvider() -> any LifecycleHooksProviding {
        DefaultLifecycleHooksProvider()
    }
    public func makeAgentLoopProvider(
        messages: any MessageManaging,
        llmManager: any LLMManaging,
        toolManager: any ToolManagerProviding,
        streaming: any MessageStreamingProviding,
        conversations: any ConversationManaging
    ) -> any AgentLoopProviding {
        DefaultAgentLoopProvider(
            messages: messages,
            llmManager: llmManager,
            toolManager: toolManager,
            streaming: streaming,
            conversations: conversations
        )
    }
    public func makeDocsViewProvider() -> any DocsViewProviding { DefaultDocsViewProviding() }
    public func makeLogoProvider() -> any LogoProviding { DefaultLogoProviding() }
    public func makeProjectProvider() -> any ProjectProviding { DefaultProjectProvider() }
    public func makeChatSectionProvider() -> any ChatSectionProviding { DefaultChatSectionProviding() }
    public func makeToolManagerProvider() -> any ToolManagerProviding { DefaultToolManagerProviding() }
    public func makePromptSuggestionProvider() -> any PromptSuggestionProviding {
        DefaultPromptSuggestionProvider()
    }
    public func makeToolbarProvider() -> any ToolbarProviding { DefaultToolbarProviding() }
    public func makeRootViewProvider() -> any RootViewProviding { DefaultRootViewProvider() }
    public func makeActivityBarProvider() -> any ActivityBarProviding { DefaultActivityBarProviding() }
    public func makeRailViewProvider() -> any RailViewProviding { DefaultRailViewProviding() }
    public func makeSettingViewProvider() -> any SettingViewProviding { DefaultSettingViewProviding() }
    public func makeCommandProvider() -> any CommandProviding { DefaultCommandProviding() }

    public func registerProviders(into kernel: KernelCoreContainer) throws {
        let storage = makeStorageProvider()
        try kernel.registerProvider((any StorageProviding).self, storage)
        kernel.stateStore = PluginEnabledStateStore(
            pluginDirectory: storage.pluginDataDirectory(for: "PluginManager")
        )

        let theme = makeThemeProvider()
        if let defaultTheme = theme as? DefaultThemeProviding {
            defaultTheme.setStorageDirectory(
                storage.pluginDataDirectory(for: "ThemeManager")
            )
        }
        try kernel.registerProvider((any ThemeProviding).self, theme)

        try kernel.registerProvider((any ContentViewProviding).self, makeContentViewProvider())
        try kernel.registerProvider((any DocsViewProviding).self, makeDocsViewProvider())
        try kernel.registerProvider((any LogoProviding).self, makeLogoProvider())
        try kernel.registerProvider((any ProjectProviding).self, makeProjectProvider())
        try kernel.registerProvider((any ChatSectionProviding).self, makeChatSectionProvider())

        let conversations = makeConversationProvider()
        try kernel.registerProvider((any ConversationManaging).self, conversations)
        let messages = makeMessageProvider()
        try kernel.registerProvider((any MessageManaging).self, messages)
        try kernel.registerProvider((any SuperLLMProvider).self, makeLLMProvider())
        let llmManager = makeLLMManagerProvider()
        try kernel.registerProvider((any LLMManaging).self, llmManager)
        let streaming = makeMessageStreamingProvider()
        try kernel.registerProvider((any MessageStreamingProviding).self, streaming)
        let lifecycleHooks = makeLifecycleHooksProvider()
        try kernel.registerProvider((any LifecycleHooksProviding).self, lifecycleHooks)

        let toolManager = makeToolManagerProvider()
        if let defaultToolManager = toolManager as? DefaultToolManagerProviding {
            defaultToolManager.recordStore = ToolCallRecordStore(
                databaseRootURL: storage.pluginDataDirectory(for: "ToolManager")
            )
        }
        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)
        let agentLoop = makeAgentLoopProvider(
            messages: messages,
            llmManager: llmManager,
            toolManager: toolManager,
            streaming: streaming,
            conversations: conversations
        )
        agentLoop.setLifecycleHooks(lifecycleHooks)
        try kernel.registerProvider((any AgentLoopProviding).self, agentLoop)
        try kernel.registerProvider(
            (any PromptSuggestionProviding).self,
            makePromptSuggestionProvider()
        )
        try kernel.registerProvider((any ToolbarProviding).self, makeToolbarProvider())
        try kernel.registerProvider((any RootViewProviding).self, makeRootViewProvider())
        try kernel.registerProvider((any ActivityBarProviding).self, makeActivityBarProvider())
        try kernel.registerProvider((any RailViewProviding).self, makeRailViewProvider())
        try kernel.registerProvider((any SettingViewProviding).self, makeSettingViewProvider())
        try kernel.registerProvider((any CommandProviding).self, makeCommandProvider())
    }
}
