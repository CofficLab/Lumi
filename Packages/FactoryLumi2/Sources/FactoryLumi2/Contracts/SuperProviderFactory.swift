import Foundation
import KernelCore
import ProviderActivityBar
import ProviderAgentLoop
import ProviderChatSection
import ProviderCommand
import ProviderContentView
import ProviderConversation
import ProviderConversationInput
import ProviderDocsView
import ProviderIdleTime
import ProviderLegacyData
import ProviderLLM
import ProviderLLMManager
import ProviderLogo
import ProviderMenuBar
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderMessageStreaming
import ProviderNetwork
import ProviderOnboarding
import ProviderPluginControl
import ProviderPluginManaging
import ProviderProject
import ProviderPromptSuggestion
import ProviderRailView
import ProviderRootView
import ProviderSettingView
import ProviderStorage
import ProviderTheme
import ProviderToast
import ProviderToolbar
import ProviderToolManager
import ProviderWebServer
import ProviderWorkspace

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

    /// 产出 `PluginManaging` 实现（插件管理：在 `PluginControlling` 之上提供
    /// SuperPlugin 的枚举、查询、卸载与重新加载）。
    func makePluginManagingProvider(
        kernel: KernelCoreContainer,
        controlling: any PluginControlling
    ) -> any PluginManaging

    func makeWebServerProvider() -> any WebServerProviding
    /// 装配并注册全部默认 Provider 到内核。
    ///
    /// 实现方负责按依赖顺序创建各 Provider 并调用 `kernel.registerProvider`，
    /// 完成 Provider 间的接线（如主题持久化目录、AgentLoop 依赖注入、
    /// 事件桥接等）。`KernelFactory.makeKernel` 只负责创建容器、调用本方法
    /// 并启动插件，不再直接持有注册逻辑。
    ///
    /// - Throws: `KernelCoreError.providerAlreadyRegistered` — 同类型重复注册时。
    func registerProviders(into kernel: KernelCoreContainer) throws
}
