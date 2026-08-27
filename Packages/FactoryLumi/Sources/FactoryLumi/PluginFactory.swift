import Foundation
import KernelCore
import PluginAgentRules
import PluginAgentTempStorage
import PluginAgentTurnNotification
import PluginDebugBadge
import PluginFileLog
import PluginShowImage
import ImageToPDFPlugin
import DownloadPlugin
import AppManagerPlugin
import ClipboardManagerPlugin
import BrowserPlugin
import ComputerUsePlugin
import BrewManagerPlugin
import DisplayControlPlugin
import PortManagerPlugin
import DockerManagerPlugin
import RegistryManagerPlugin
import RClickPlugin
import InputPlugin
import BookletMakerPlugin
import ScreenRecorderPlugin
import StoryWriterPlugin
import QuickFileSearchPlugin
import ProjectOverviewPlugin
import QuickLauncherPlugin
import TextActionsPlugin
import TerminalPlugin
import DatabaseManagerPlugin
import GitPlugin
import GoalTaskPlugin
import PluginStorage
import PluginToast
import PluginCommand
import PluginActivityBar
import PluginAppIconDesigner
import PluginAppStorePromoDesigner
import PluginAskUser
import PluginCaffeinate
import PluginChatFileAttachment
import PluginChatPanel
import PluginChatScreenshot
import PluginConversationBehavior
import PluginConversationFork
import PluginConversationInput
import PluginConversationList
import PluginConversationManager
import PluginConversationMode
import PluginConversationStats
import PluginConversationNew
import PluginConversationPendingMessage
import PluginConversationTitle
import PluginConversationState
import PluginDevice
import PluginDiskManager
import PluginNetworkManager
import PluginDocxRead
import PluginHostsManager
import PluginIdleTime
import PluginActivityHeatmap
import PluginLLMProviderAiRouter
import PluginLLMManager
import PluginLLMProviderAliyun
import PluginLLMProviderAnthropic
import PluginLLMProviderDeepSeek
import PluginLLMProviderFeifeimiao
import PluginLLMProviderFlyMux
import PluginLLMProviderHappyCode
import PluginLLMProviderHyperAPI
import PluginLLMProviderKimiCode
import PluginLLMProviderLPgpt
import PluginLLMProviderMegaLLM
import PluginLLMProviderMiniMax
import PluginLLMProviderOpenAI
import PluginLLMProviderOpenCode
import PluginLLMProviderOpenRouter
import PluginLLMProviderSettings
import PluginLLMProviderStepFun
import PluginLLMProviderSublyx
import PluginLLMProviderXiaomi
import PluginLLMProviderXybbz
import PluginLLMProviderZhipu
import PluginLLMProviderCodex
import PluginLLMProviderMLX
import PluginLogoCoffic
import PluginLogoManager
import PluginLogoSmartLight
import PluginMemory
import PluginMessageList
import PluginMessageManager
import PluginMessageRenderer
import PluginAgentLoop
import PluginMessageSender
import PluginMindMapDesigner
import PluginModelSelector
import PluginOcr
import PluginOpenIn
import PluginPluginManager
import PluginProjects
import PluginProjectRAG
import PluginResumeDesigner
import PluginSettingGeneral
import PluginSettingView
import PluginSkill
import PluginStateMonitor
import PluginOnboarding
import PluginThemePack
import PluginToolManager
import PluginToolbarSettings
import PluginVideoConverter
import PluginWebFetch
import PluginWebSearch
import PluginWebServer
import PluginWhiteNoise
import NettoPlugin

/// 默认 `PluginFactory` 实现：产出默认插件。
@MainActor
public struct DefaultPluginFactory: PluginFactory {
    public init() {}

    /// 产出默认插件列表。
    public func makePlugins() -> [any SuperPlugin] {
        [
            // 核心基础插件（order 10-20）：必须最先启动
            try! StorageSuperPlugin(),
            CommandPlugin(),
            ToastSuperPlugin(),
            CaffeinatePlugin(),
            SettingGeneralPlugin(),
            ProjectsPlugin(),
            // 原 LumiApp 显式注入的项目 RAG：保留旧索引数据库和 search_code 工具。
            ProjectRAGSuperPlugin(),
            DevicePlugin(),
            HostsManagerPlugin(),
            DiskManagerPlugin(),
            NetworkManagerPlugin(),
            DocxReadPlugin(),
            WebFetchPlugin(),
            WebSearchPlugin(),
            WebServerPlugin(),
            AgentRulesPlugin(),
            AgentTempStoragePlugin(),
            OcrPlugin(),
            AppIconDesignerPlugin(),
            AppStorePromoDesignerPlugin(),
            MindMapDesignerPlugin(),
            ResumeDesignerPlugin(),
            // ActivityBar 自定义实现：替换 ProviderFactory 预注册的 DefaultActivityBarProviding，
            // 必须在所有 onBoot 中调用 addItems 的业务插件（如 ResumeDesignerPlugin order=81）之前。
            PluginActivityBar(),
            LogoCofficPlugin(),
            LogoSmartLightPlugin(),
            SettingsToolbarPlugin(),
            ThemePackPlugin(),
            VideoConverterPlugin(),
            WhiteNoisePlugin(),
            IdleTimePlugin(),
            ActivityHeatmapPlugin(),
            ChatPanelPlugin(),
            ChatFileAttachmentPlugin(),
            ChatScreenshotPlugin(),
            ConversationModePlugin(),
            ConversationVerbosityPlugin(),
            ConversationLanguagePlugin(),
            ConversationReasoningPlugin(),
            // 会话统计：消息计数 / 缓存命中率 / 上下文用量
            ConversationMessageCountPlugin(),
            ConversationCacheHitRatePlugin(),
            ConversationContextSizePlugin(),
            ConversationSpeedPlugin(),
            ConversationAgentTurnCountPlugin(),
            ConversationTitlePlugin(),
            ConversationStatePlugin(),
            ConversationPendingMessagePlugin(),
            ConversationForkPlugin(),
            AskUserPlugin(),
            OpenInPlugin(),
            AgentTurnNotificationPlugin(),
            DebugBadgeSuperPlugin(),
            FileLogPlugin(),
            ShowImagePlugin(),
            ImageToPDFSuperPlugin(),
            DownloadSuperPlugin(),
            AppManagerSuperPlugin(),
            ClipboardManagerSuperPlugin(),
            BrowserSuperPlugin(),
            ComputerUseSuperPlugin(),
            BrewManagerSuperPlugin(),
            DisplayControlSuperPlugin(),
            PortManagerSuperPlugin(),
            DockerManagerSuperPlugin(),
            RegistryManagerSuperPlugin(),
            RClickSuperPlugin(),
            InputSuperPlugin(),
            BookletMakerPlugin(),
            ScreenRecorderSuperPlugin(),
            StoryWriterSuperPlugin(),
            QuickFileSearchSuperPlugin(),
            ProjectOverviewSuperPlugin(),
            QuickLauncherSuperPlugin(),
            TextActionsSuperPlugin(),
            TerminalSuperPlugin(),
            DatabaseManagerSuperPlugin(),
            GitSourceControlSuperPlugin(),
            GoalTaskSuperPlugin(),
            NettoSuperPlugin(),
            SkillPlugin(),
            StateMonitorPlugin(),
            OnboardingPlugin(),
            MemoryPlugin(),
            ModelSelectorPlugin(),
            MessageListPlugin(),
            MessageRendererPlugin(),
            ConversationInputPlugin(),
            ConversationListPlugin(),
            ConversationNewPlugin(),
            ConversationManagerPlugin(),
            MessageManagerPlugin(),
            PluginAgentLoop(),
            MessageSenderPlugin(),
            PluginPluginManager(),
            // 设置视图管理器：替换 ProviderFactory 预注册的默认 SettingViewProviding 实现，
            // 必须先于各设置入口贡献插件（如 SettingGeneralPlugin order=200）。
            PluginSettingView(),
            // Logo 管理器：替换 ProviderFactory 预注册的默认 LogoProviding 实现，
            // 必须先于各 Logo 贡献插件（如 LogoCofficPlugin order=100）。
            PluginLogoManager(),
            // LLM 供应商管理器：替换 ProviderFactory 预注册的默认实现，
            // 必须早于 PluginAgentLoop(order=8) 与各供应商插件(order=100)。
            PluginLLMManager(),
            // 工具管理器：替换默认 ToolManagerProviding 并注册内置工具，
            // 必须早于 PluginAgentLoop(order=8)。
            PluginToolManager(),
            AiRouterProviderPlugin(),
            AliyunProviderPlugin(),
            AnthropicProviderPlugin(),
            DeepSeekProviderPlugin(),
            FeifeimiaoProviderPlugin(),
            FlyMuxProviderPlugin(),
            HappyCodeProviderPlugin(),
            HyperAPIProviderPlugin(),
            KimiCodeProviderPlugin(),
            LPgptProviderPlugin(),
            MegaLLMProviderPlugin(),
            MiniMaxProviderPlugin(),
            OpenAIProviderPlugin(),
            OpenCodeProviderPlugin(),
            OpenRouterProviderPlugin(),
            StepFunProviderPlugin(),
            SublyxProviderPlugin(),
            XiaomiProviderPlugin(),
            XybbzProviderPlugin(),
            ZhipuProviderPlugin(),
            CodexLumiPlugin(),
            MLXProviderPlugin(),
            LLMProviderSettingsPlugin(),
        ]
    }
}

/// V2 plugin catalog filtered to an explicit host allow-list.
///
/// Dedicated applications can retain the old `FactoryLumi.configuration`
/// behavior while moving their composition root to `KernelCore`. Filtering is
/// performed before kernel startup, so excluded plugins never boot or publish
/// UI contributions.
@MainActor
public struct SelectedPluginFactory: PluginFactory {
    private let base: any PluginFactory
    public let allowedPluginIDs: Set<String>

    public init(allowedPluginIDs: Set<String>) {
        self.allowedPluginIDs = allowedPluginIDs
        self.base = DefaultPluginFactory()
    }

    public init(
        allowedPluginIDs: Set<String>,
        base: any PluginFactory
    ) {
        self.allowedPluginIDs = allowedPluginIDs
        self.base = base
    }

    public func makePlugins() -> [any SuperPlugin] {
        base.makePlugins().filter { allowedPluginIDs.contains($0.id) }
    }
}
