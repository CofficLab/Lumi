import Foundation
import ProviderActivityBar
import ProviderContentView
import ProviderChatSection
import ProviderMessage
import ProviderAgentLoop
import ProviderLLM
import ProviderMessageSender
import ProviderConversation
import ProviderDocsView
import ProviderLogo
import ProviderMenuBar
import ProviderNetwork
import ProviderProject
import ProviderRailView
import ProviderRootView
import ProviderSettingView
import ProviderStorage
import ProviderTheme
import ProviderToast
import ProviderToolbar
import ProviderToolManager
import ProviderAgentTurn
import ProviderConversationInput
import ProviderMessageStreaming
import ProviderMessageRendering
import ProviderPromptSuggestion
import ProviderWorkspace
import ProviderOnboarding
import ProviderCommand
import ProviderIdleTime
import ProviderLegacyData
import ProviderPluginControl
import ProviderWebServer
import ProviderLLMManager
import KernelCore

/// 产出各种 Provider 实现的工厂协议。
///
/// 集中管理 Provider 的构造逻辑；`KernelFactory.makeKernel` 直接调用它
/// 产出各 Provider 并注册进 KernelCore。宿主可实现该协议覆盖
/// 个别 Provider 的产出逻辑。
@MainActor
public protocol ProviderFactory {
    /// 产出 `StorageProviding` 实现。
    func makeStorageProvider() -> any StorageProviding

    /// 产出 `ThemeProviding` 实现。
    func makeThemeProvider() -> any ThemeProviding

    /// 产出 `ContentViewProviding` 实现。
    func makeContentViewProvider() -> any ContentViewProviding

    /// 产出聊天区域 Provider。
    func makeChatSectionProvider() -> any ChatSectionProviding

    func makeConversationProvider() -> any ConversationManaging
    func makeMessageProvider() -> any MessageManaging
    func makeAgentLoopProvider(messages: any MessageManaging) -> any AgentLoopProviding
    func makeLLMProvider() -> any LLMProviding
    func makeMessageSenderProvider(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        agentLoop: any AgentLoopProviding
    ) -> any MessageSendingProviding

    /// 产出 `LLMProviderManagerProviding` 实现（各 LLM 供应商的注册表 + 选中路由）。
    ///
    /// 管理器自身即 `LLMProviding`：`complete(_:)` 路由到选中的供应商，
    /// LLM Provider 插件在 `onBoot` 中把各自供应商注册进来即可生效。
    func makeLLMProviderManagerProvider() -> any LLMProviderManagerProviding

    /// 产出 `DocsViewProviding` 实现。
    func makeDocsViewProvider() -> any DocsViewProviding

    /// 产出 `MenuBarProviding` 实现。
    func makeMenuBarProvider() -> any MenuBarProviding

    /// 产出 `LogoProviding` 实现。
    func makeLogoProvider() -> any LogoProviding

    /// 产出 `ProjectProviding` 实现。
    func makeProjectProvider() -> any ProjectProviding

    /// 产出 `ToastProviding` 实现。
    func makeToastProvider() -> any ToastProviding

    /// 产出 `NetworkProviding` 实现。
    func makeNetworkProvider() -> any NetworkProviding

    /// 产出 `ToolbarProviding` 实现。
    func makeToolbarProvider() -> any ToolbarProviding

    /// 产出 `RootViewProviding` 实现。
    func makeRootViewProvider() -> any RootViewProviding

    /// 产出 `ActivityBarProviding` 实现。
    func makeActivityBarProvider() -> any ActivityBarProviding

    /// 产出 `RailViewProviding` 实现。
    func makeRailViewProvider() -> any RailViewProviding

    /// 产出 `SettingViewProviding` 实现。
    func makeSettingViewProvider() -> any SettingViewProviding

    /// 产出 `ToolManagerProviding` 实现（Agent 工具注册/执行/记录）。
    func makeToolManagerProvider() -> any ToolManagerProviding

    func makeAgentTurnProvider() -> any AgentTurnProviding
    func makeConversationInputProvider() -> any ConversationInputProviding
    func makeMessageStreamingProvider() -> any MessageStreamingProviding
    func makeMessageRenderingProvider() -> any MessageRenderingProviding
    func makePromptSuggestionProvider() -> any PromptSuggestionProviding
    func makeWorkspaceProvider(storage: any StorageProviding) -> any WorkspaceProviding
    func makeOnboardingProvider() -> any OnboardingProviding
    func makeCommandProvider() -> any CommandProviding
    func makeIdleTimeProvider(storage: any StorageProviding) -> any IdleTimeProviding
    func makeLegacyDataProvider() -> any LegacyDataProviding
    func makePluginControlProvider(kernel: KernelCoreContainer) -> any PluginControlling
    func makeWebServerProvider() -> any WebServerProviding
}

/// 默认 `ProviderFactory` 实现：产出各 Provider 的默认实现。
@MainActor
public struct DefaultProviderFactory: ProviderFactory {
    public init() {}

    /// 产出 `StorageProviding` 实现（默认 Application Support 磁盘存储）。
    public func makeStorageProvider() -> any StorageProviding {
        DefaultStorageProviding()
    }

    /// 产出 `ThemeProviding` 实现（默认内置主题注册表 + 选中持久化）。
    public func makeThemeProvider() -> any ThemeProviding {
        DefaultThemeProviding()
    }

    /// 产出 `ContentViewProviding` 实现（默认持有当前内容视图）。
    public func makeContentViewProvider() -> any ContentViewProviding {
        DefaultContentViewProviding()
    }

    public func makeChatSectionProvider() -> any ChatSectionProviding {
        DefaultChatSectionProviding()
    }

    public func makeMessageProvider() -> any MessageManaging {
        DefaultMessageManaging()
    }

    public func makeAgentLoopProvider(messages: any MessageManaging) -> any AgentLoopProviding {
        DefaultAgentLoopProviding(messages: messages)
    }

    public func makeLLMProvider() -> any LLMProviding {
        DefaultLLMProviding()
    }

    public func makeLLMProviderManagerProvider() -> any LLMProviderManagerProviding {
        DefaultLLMProviderManagerProviding()
    }

    public func makeMessageSenderProvider(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        agentLoop: any AgentLoopProviding
    ) -> any MessageSendingProviding {
        DefaultMessageSendingProviding(
            conversations: conversations,
            messages: messages,
            agentLoop: agentLoop
        )
    }

    /// 产出 `ConversationManaging` 实现（默认内存实现，无持久化）。
    public func makeConversationProvider() -> any ConversationManaging {
        DefaultConversationManaging()
    }

    /// 产出 `DocsViewProviding` 实现（默认持有文档条目数组）。
    public func makeDocsViewProvider() -> any DocsViewProviding {
        DefaultDocsViewProviding()
    }

    /// 产出 `MenuBarProviding` 实现（默认持有菜单栏条目数组）。
    public func makeMenuBarProvider() -> any MenuBarProviding {
        DefaultMenuBarProviding()
    }

    /// 产出 `LogoProviding` 实现（默认持有 Logo 项集合）。
    public func makeLogoProvider() -> any LogoProviding {
        DefaultLogoProviding()
    }

    /// 产出 `ProjectProviding` 实现（默认内存实现）。
    public func makeProjectProvider() -> any ProjectProviding {
        DefaultProjectProviding()
    }

    /// 产出 `ToastProviding` 实现（默认 no-op 实现）。
    public func makeToastProvider() -> any ToastProviding {
        DefaultToastProviding()
    }

    /// 产出 `NetworkProviding` 实现（默认 URLSession 实现）。
    public func makeNetworkProvider() -> any NetworkProviding {
        DefaultNetworkProviding()
    }

    /// 产出 `ToolbarProviding` 实现（默认按 placement 渲染的工具栏）。
    public func makeToolbarProvider() -> any ToolbarProviding {
        DefaultToolbarProviding()
    }

    /// 产出 `RootViewProviding` 实现（默认「工具栏 + 内容区」根布局）。
    public func makeRootViewProvider() -> any RootViewProviding {
        DefaultRootViewProviding()
    }

    /// 产出 `ActivityBarProviding` 实现（默认竖直入口栏）。
    public func makeActivityBarProvider() -> any ActivityBarProviding {
        DefaultActivityBarProviding()
    }

    /// 产出 `RailViewProviding` 实现（默认侧边栏标签 + 内容）。
    public func makeRailViewProvider() -> any RailViewProviding {
        DefaultRailViewProviding()
    }

    /// 产出 `SettingViewProviding` 实现（默认最简设置视图）。
    public func makeSettingViewProvider() -> any SettingViewProviding {
        DefaultSettingViewProviding()
    }

    /// 产出 `ToolManagerProviding` 实现（默认内存注册表 + SwiftData 记录存储）。
    public func makeToolManagerProvider() -> any ToolManagerProviding {
        DefaultToolManagerProviding()
    }

    public func makeAgentTurnProvider() -> any AgentTurnProviding {
        DefaultAgentTurnProviding()
    }

    public func makeConversationInputProvider() -> any ConversationInputProviding {
        DefaultConversationInputProviding()
    }

    public func makeMessageStreamingProvider() -> any MessageStreamingProviding {
        DefaultMessageStreamingProviding()
    }

    public func makeMessageRenderingProvider() -> any MessageRenderingProviding {
        DefaultMessageRenderingProviding()
    }

    public func makePromptSuggestionProvider() -> any PromptSuggestionProviding {
        DefaultPromptSuggestionProviding()
    }

    public func makeWorkspaceProvider(storage: any StorageProviding) -> any WorkspaceProviding {
        DefaultWorkspaceProviding(pluginDirectory: storage.pluginDataDirectory(for: "LayoutKernel"))
    }

    public func makeOnboardingProvider() -> any OnboardingProviding {
        DefaultOnboardingProviding()
    }

    public func makeCommandProvider() -> any CommandProviding {
        DefaultCommandProviding()
    }

    public func makeIdleTimeProvider(storage: any StorageProviding) -> any IdleTimeProviding {
        // 完整实现：事件持久化 + 休息窗口推断，数据目录遵循 Storage 约定
        // （<数据根目录>/Plugins/IdleTime/）。
        IdleTimeService(store: IdleActivityStore(directoryURL: storage.pluginDataDirectory(for: "IdleTime")))
    }

    public func makeLegacyDataProvider() -> any LegacyDataProviding {
        DefaultLegacyDataProviding()
    }

    public func makePluginControlProvider(kernel: KernelCoreContainer) -> any PluginControlling {
        DefaultPluginControlling(kernel: kernel)
    }

    public func makeWebServerProvider() -> any WebServerProviding {
        DefaultWebServerProviding()
    }
}
