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
import ProviderPluginManaging
import ProviderWebServer
import ProviderLLMManager
import KernelCore

/// 默认 `ProviderFactory` 实现：产出各 Provider 的默认实现。
@MainActor
public struct DefaultProviderFactory: ProviderFactory {
    public init() {}

    /// 产出 `StorageProviding` 实现（默认 Application Support 磁盘存储）。
    public func makeStorageProvider() -> any StorageProviding {
        DefaultStorageProvider()
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
        DefaultMessageManager()
    }

    public func makeAgentLoopProvider(messages: any MessageManaging) -> any AgentLoopProviding {
        DefaultAgentLoopProvider(messages: messages)
    }

    public func makeLLMProvider() -> any LLMProviding {
        DefaultLLMProviding()
    }

    public func makeLLMProviderManagerProvider() -> any LLMProviderManagerProviding {
        DefaultLLMProviderManagerProviding()
    }

    /// 产出 `MessageSendingProviding` 实现的工厂钩子。
    ///
    /// 默认注册职责已移交 `PluginMessageSender.MessageSenderPlugin`（onBoot 中
    /// 解析基础 Provider 并注册），宿主如需定制实现，可覆盖本方法并自行注册。
    public func makeMessageSenderProvider(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        agentLoop: any AgentLoopProviding
    ) -> any MessageSendingProviding {
        DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: agentLoop
        )
    }

    /// 产出 `ConversationManaging` 实现（默认内存实现，无持久化）。
    public func makeConversationProvider() -> any ConversationManaging {
        DefaultConversationManager()
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

    public func makeConversationInputProvider() -> any ConversationInputProviding {
        DefaultConversationInputProvider()
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
        // （<数据根目录>/IdleTime/）。
        IdleTimeService(store: IdleActivityStore(directoryURL: storage.pluginDataDirectory(for: "IdleTime")))
    }

    public func makeLegacyDataProvider() -> any LegacyDataProviding {
        DefaultLegacyDataProviding()
    }

    public func makePluginControlProvider(kernel: KernelCoreContainer) -> any PluginControlling {
        DefaultPluginControlling(kernel: kernel)
    }

    public func makePluginManagingProvider(
        kernel: KernelCoreContainer,
        controlling: any PluginControlling
    ) -> any PluginManaging {
        DefaultPluginManaging(kernel: kernel, controlling: controlling)
    }

    public func makeWebServerProvider() -> any WebServerProviding {
        DefaultWebServerProviding()
    }

    // MARK: - Provider Registration

    /// 装配并注册全部默认 Provider，完成依赖接线。
    ///
    /// 由 `KernelFactory.makeKernel` 调用：工厂只负责产出与注册，
    /// 内核生命周期（`start(plugins:)`）与插件装配留在 KernelFactory。
    public func registerProviders(into kernel: KernelCoreContainer) throws {
        try kernel.registerProvider((any StorageProviding).self, makeStorageProvider())

        // 主题 Provider：选中主题持久化遵循 Storage 约定
        // （<数据根目录>/ThemeManager/theme-selection.plist）。
        let themeProvider = makeThemeProvider()
        if let storage = kernel.resolveProvider((any StorageProviding).self),
           let defaultTheme = themeProvider as? DefaultThemeProviding {
            defaultTheme.setStorageDirectory(storage.pluginDataDirectory(for: "ThemeManager"))
        }
        try kernel.registerProvider((any ThemeProviding).self, themeProvider)

        try kernel.registerProvider((any ContentViewProviding).self, makeContentViewProvider())
        try kernel.registerProvider((any ChatSectionProviding).self, makeChatSectionProvider())

        let conversations = makeConversationProvider()
        try kernel.registerProvider((any ConversationManaging).self, conversations)

        let messages = makeMessageProvider()
        try kernel.registerProvider((any MessageManaging).self, messages, forwardsObjectWillChange: false)

        let llmProvider = makeLLMProvider()
        try kernel.registerProvider((any LLMProviding).self, llmProvider)

        // 流式输出 store：先于 AgentLoop 注册，供回合循环写入临时行
        // （高频变更，不转发 objectWillChange，由消费方窄播订阅）。
        try kernel.registerProvider(
            (any MessageStreamingProviding).self,
            makeMessageStreamingProvider(),
            forwardsObjectWillChange: false
        )

        // LLM Provider 管理器：各 LLM 供应商（ManagedLLMProvider）的注册表 +
        // 选中持久化 + 路由发送。管理器自身即 `LLMProviding`，AgentLoop 直接
        // 注入它，把请求路由到选中的供应商。
        let providerManager = makeLLMProviderManagerProvider()
        try kernel.registerProvider((any LLMProviderManagerProviding).self, providerManager)

        let agentLoop = makeAgentLoopProvider(messages: messages)
        agentLoop.setLLMProvider(providerManager)
        // 完整接线（复刻旧版 AgentTurnRunner 的依赖注入）：
        // - 工具执行/授权（build 模式高风险调用需用户批准）
        // - 流式输出（MessageStreaming 临时行，UI 读 store 渲染）
        // - 会话设置（automationLevel / reasoningEffort / verbosity / language）
        // - 回合生命周期事件 → 内核事件总线 + 旧 NotificationCenter 通知名
        let toolManager = makeToolManagerProvider()
        if let storage = kernel.resolveProvider((any StorageProviding).self),
           let defaultToolManager = toolManager as? DefaultToolManagerProviding {
            defaultToolManager.recordStore = ToolCallRecordStore(
                databaseRootURL: storage.pluginDataDirectory(for: "ToolManager")
            )
        }
        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)
        agentLoop.setToolManager(toolManager)
        agentLoop.setStreaming(kernel.resolveProvider((any MessageStreamingProviding).self))
        agentLoop.setConversations(conversations)
        agentLoop.setEventHandler { [weak kernel] event in
            guard let kernel else { return }
            Self.bridge(agentLoopEvent: event, kernel: kernel)
        }
        try kernel.registerProvider((any AgentLoopProviding).self, agentLoop, forwardsObjectWillChange: false)

        // `MessageSendingProviding` 不再由工厂装配注册：改由 `PluginMessageSender`
        // （`MessageSenderPlugin`，order=9）在 onBoot 中解析上述 conversations /
        // messages / agentLoop 并注册，与消费方插件共享同一实例。宿主如需定制
        // 产出逻辑，可覆盖 `makeMessageSenderProvider` 或替换插件列表。
        try kernel.registerProvider((any ConversationInputProviding).self, makeConversationInputProvider())
        try kernel.registerProvider((any MessageRenderingProviding).self, makeMessageRenderingProvider())
        try kernel.registerProvider((any PromptSuggestionProviding).self, makePromptSuggestionProvider())
        guard let storage = kernel.resolveProvider((any StorageProviding).self) else {
            throw KernelCoreError.providerNotRegistered(type: (any StorageProviding).self)
        }
        try kernel.registerProvider(
            (any WorkspaceProviding).self,
            makeWorkspaceProvider(storage: storage)
        )
        try kernel.registerProvider((any OnboardingProviding).self, makeOnboardingProvider())
        try kernel.registerProvider((any CommandProviding).self, makeCommandProvider())
        try kernel.registerProvider((any IdleTimeProviding).self, makeIdleTimeProvider(storage: storage))
        try kernel.registerProvider((any LegacyDataProviding).self, makeLegacyDataProvider())
        try kernel.registerProvider(
            (any PluginControlling).self,
            makePluginControlProvider(kernel: kernel)
        )
        // 插件管理：基于真实 PluginControlling 实例装配，二者共享同一内核状态。
        let pluginControlling = kernel.resolveProvider((any PluginControlling).self)
        try kernel.registerProvider(
            (any PluginManaging).self,
            makePluginManagingProvider(
                kernel: kernel,
                controlling: pluginControlling ?? DefaultPluginControlling(kernel: kernel)
            )
        )
        try kernel.registerProvider((any WebServerProviding).self, makeWebServerProvider())
        try kernel.registerProvider((any DocsViewProviding).self, makeDocsViewProvider())
        try kernel.registerProvider((any MenuBarProviding).self, makeMenuBarProvider())
        try kernel.registerProvider((any LogoProviding).self, makeLogoProvider())
        try kernel.registerProvider((any ProjectProviding).self, makeProjectProvider())
        try kernel.registerProvider((any ToastProviding).self, makeToastProvider())
        try kernel.registerProvider((any NetworkProviding).self, makeNetworkProvider())
        try kernel.registerProvider((any ToolbarProviding).self, makeToolbarProvider())
        try kernel.registerProvider((any RootViewProviding).self, makeRootViewProvider())
        try kernel.registerProvider((any ActivityBarProviding).self, makeActivityBarProvider())
        try kernel.registerProvider((any RailViewProviding).self, makeRailViewProvider())
        try kernel.registerProvider((any SettingViewProviding).self, makeSettingViewProvider())
    }

    // MARK: - Agent Loop Event Bridging

    /// 把 Agent 回合生命周期事件桥接到内核事件总线 + 旧 NotificationCenter 通知名。
    ///
    /// 复刻旧版 `LumiEventManager` 的 4 种通知（lumiTurnStarted / lumiMessageSaved /
    /// lumiTurnCompleted / lumiTurnFinished），通知 userInfo 键与旧版一致，让
    /// 尚未迁移的 NotificationCenter 消费者继续工作；同时发布类型化事件
    /// （`AgentLoopBridgedEvent`），供新架构插件订阅。
    private static func bridge(agentLoopEvent event: AgentLoopEvent, kernel: KernelCoreContainer) {
        switch event {
        case let .turnStarted(conversationID, turnID):
            kernel.eventBus.publishAsLegacy(
                AgentLoopBridgedEvent(event),
                notificationName: .lumiTurnStarted,
                userInfo: [
                    "conversationID": conversationID,
                    "turnID": turnID,
                ]
            )
        case let .messageSaved(conversationID, messageID, role):
            kernel.eventBus.publishAsLegacy(
                AgentLoopBridgedEvent(event),
                notificationName: .lumiMessageSaved,
                userInfo: [
                    "messageID": messageID,
                    "conversationID": conversationID,
                    "role": role,
                ]
            )
        case let .turnCompleted(conversationID, turnID):
            kernel.eventBus.publishAsLegacy(
                AgentLoopBridgedEvent(event),
                notificationName: .lumiTurnCompleted,
                userInfo: [
                    "conversationID": conversationID,
                    "turnID": turnID,
                ]
            )
        case let .turnFinished(conversationID, turnID, reason):
            kernel.eventBus.publishAsLegacy(
                AgentLoopBridgedEvent(event),
                notificationName: .lumiTurnFinished,
                userInfo: [
                    "conversationID": conversationID,
                    "turnID": turnID as Any,
                    "reason": reason.rawValue,
                ]
            )
        }
    }
}

/// 内核事件总线用的 AgentLoop 事件包装。
///
/// `AgentLoopEvent` 定义在 ProviderAgentLoop（不依赖 KernelCore），无法直接
/// conform `KernelEvent`；此处包装为 `KernelEvent` 让新架构插件可订阅类型化事件。
public struct AgentLoopBridgedEvent: KernelEvent {
    public let event: AgentLoopEvent
    public init(_ event: AgentLoopEvent) {
        self.event = event
    }
}
