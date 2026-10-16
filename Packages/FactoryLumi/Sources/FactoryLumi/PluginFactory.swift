import Foundation
import KernelCore
import ProviderChatSection
import PluginACP
import PluginAgentRules
import PluginAgentTempStorage
import PluginAgentPlanStorage
import PluginAgentTurnNotification
import PluginDeveloperMode
import PluginFileLog
import PluginShowImage
import ImageToPDFPlugin
import DownloadPlugin
import AppManagerPlugin
import ClipboardManagerPlugin
import BrowserPlugin
import ComputerUsePlugin
import PluginMCP
import PluginXcodeMCP
import PluginGithubMCP
import BrewManagerPlugin
import DisplayControlPlugin
import PortManagerPlugin
import DockerManagerPlugin
import RegistryManagerPlugin
import RClickPlugin
import InputPlugin
import PluginBookletMaker
import ScreenRecorderPlugin
import StoryWriterPlugin
import QuickFileSearchPlugin
import ProjectOverviewPlugin
import QuickLauncherPlugin
import TextActionsPlugin
import TerminalPlugin
import DatabaseManagerPlugin
import PluginMail
import GitPlugin
import PluginGitRepositoryWatch
import PluginGitWorkspace
import GoalTaskPlugin
import PluginStorage
import PluginToast
import PluginCommand
import PluginActivityBar
import PluginRootView
import PluginAppIconDesigner
import PluginAppStoreConnect
import PluginAppStorePromoDesigner
import PluginPrototypeDesigner
import PluginAskUser
import PluginCaffeinate
import PluginChatFileAttachment
import PluginChatPanel
import PluginChatScreenshot
import PluginConversationBehavior
import PluginConversationExport
import PluginConversationVerbosity
import PluginConversationCacheHitRate
import PluginConversationFork
import PluginConversationInput
import PluginConversationList
import PluginConversationManager
import PluginConversationMode
import PluginConversationStats
import PluginConversationSpeed
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
import PluginLLMProviderCommandCode
import PluginLLMProviderOpenRouter
import PluginLLMProviderSettings
import PluginLLMProviderStepFun
import PluginLLMProviderSublyx
import PluginLLMProviderTencent
import PluginLLMProviderUITest
import PluginLLMProviderXiaomi
import PluginLLMProviderXybbz
import PluginLLMProviderZhipu
import PluginLLMProviderCodex
import PluginLLMProviderMLX
import PluginLogoCoffic
import PluginLogoManager
import PluginLogoSmartLight
import PluginMemory
import PluginMessageListEmpty
import PluginMessageListBrief
import PluginMessageListStandard
import PluginMessageListDetailed
import PluginMessageManager
import PluginMessageRenderer
import PluginMessageSender
import PluginAgentLoop
import PluginAgentLoopRetry
import PluginLLMContext
import PluginMindMapDesigner
import PluginModelSelector
import PluginOcr
import PluginOpenInAntigravity
import PluginOpenInCursor
import PluginOpenInFinder
import PluginOpenInGitHubDesktop
import PluginOpenInGitOK
import PluginOpenInVSCode
import PluginOpenInXcode
import PluginPluginManager
import PluginProjects
import PluginProjectFileTree
import PluginProjectFiles
import PluginCodeEditorHost
import PluginCodeEditorLanguages
import PluginCodeEditor
import PluginEditorPreview
import PluginProjectRAG
import PluginResumeDesigner
import PluginSettingGeneral
import PluginSettingView
import PluginPerformanceMetrics
import PluginSystemBenchmark
import PluginSkill
import PluginOnboarding
import PluginWelcome
import PluginThemePack
import PluginThemeManager
import PluginToolManager
import PluginToolActivity
import PluginToolbar
import PluginToolbarSettings
import PluginVideoConverter
import PluginWebFetch
import PluginWebSearch
import PluginWebServer
import PluginWhiteNoise
import PluginXcodeBuild
import NettoPlugin

/// Booklet Maker 工作台代理：把聊天区显隐收敛到 Lumi 侧。
///
/// 共享包 `PluginBookletMaker` 不依赖 `ProviderChatSection`（GameFactory 无聊天区），
/// 改由宿主注入 `onWorkspaceActivate` / `onWorkspaceDeactivate` 闭包。
///
/// Provider 在 `ProviderFactory.registerProviders` 阶段即完成注册，早于插件启动，
/// 因此这里在 `makePlugins()` 之前从全局装配入口取得容器即可；容器为 nil 时
/// 闭包退化为空操作，不影响插件其余行为。
@MainActor
private final class BookletMakerChatVisibilityProxy {
    private weak var kernel: KernelCoreContainer?

    func attach(kernel: KernelCoreContainer) {
        self.kernel = kernel
    }

    func activate() {
        kernel?.resolveProvider((any ChatSectionProviding).self)?.setVisible(false)
    }

    func deactivate() {
        kernel?.resolveProvider((any ChatSectionProviding).self)?.setVisible(true)
    }
}

/// 默认 `PluginFactory` 实现：产出默认插件。
@MainActor
public struct DefaultPluginFactory: PluginFactory {
    private let chatVisibility = BookletMakerChatVisibilityProxy()

    public init() {}

    /// Provider 就位后回填聊天区代理，使其能在工作台切换时解析
    /// `ChatSectionProviding`。`makePlugins()` 早于 Provider 注册，故在此补齐。
    public func didRegisterProviders(in kernel: KernelCoreContainer) {
        chatVisibility.attach(kernel: kernel)
    }

    /// 产出默认插件列表。
    public func makePlugins() -> [any SuperPlugin] {
        var plugins: [any SuperPlugin] = [
            // 核心基础插件（order 10-20）：必须最先启动
            try! StorageSuperPlugin(),
            CommandPlugin(),
            // 共享工具栏插件在 onReady 同步 macOS 与 iOS 的插件贡献启用状态。
            PluginToolbar(),
            ToastSuperPlugin(),
            CaffeinatePlugin(),
            SettingGeneralPlugin(),
            // 底部面板宿主（order 12）：在 EditorPreview / Terminal 之前注册
            // PanelBottomProviding，承载 content footer 的 tab 容器。
            PanelBottomPlugin(),
            CodeEditorHostPlugin(),
            EditorPreviewPlugin(),
            CodeEditorLanguagesPlugin(),
            ProjectsPlugin(),
            // 原 LumiApp 显式注入的项目 RAG：保留旧索引数据库和 search_code 工具。
            ProjectRAGPlugin(),
            // 项目文件树（由旧版 Plugins/ProjectFileTreePlugin 迁移而来）。
            ProjectFileTreePlugin(),
            ProjectFilesPlugin(),
            DevicePlugin(),
            SystemBenchmarkPlugin(),
            HostsManagerPlugin(),
            DiskManagerPlugin(),
            NetworkManagerPlugin(),
            DocxReadPlugin(),
            WebFetchPlugin(),
            WebSearchPlugin(),
            WebServerPlugin(),
            AgentRulesPlugin(),
            AgentTempStoragePlugin(),
            AgentPlanStoragePlugin(),
            OcrPlugin(),
            AppStoreConnectPlugin(),
            AppIconDesignerPlugin(),
            AppStorePromoDesignerPlugin(),
            MindMapDesignerPlugin(),
            ResumeDesignerPlugin(),
            PrototypeDesignerPlugin(),
            // ActivityBar 自定义实现：替换 ProviderFactory 预注册的 DefaultActivityBarProviding，
            // 必须在所有 onBoot 中调用 addItems 的业务插件（如 ResumeDesignerPlugin order=81）之前。
            PluginActivityBar(),
            CodeEditorPlugin(),
            LogoCofficPlugin(),
            LogoSmartLightPlugin(),
            SettingsToolbarPlugin(),
            ThemeManagerPlugin(),
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
            // 会话统计：上下文用量
            ConversationCacheHitRatePlugin(),
            ConversationSpeedPlugin(),
            ConversationAgentTurnCountPlugin(),
            ConversationTitlePlugin(),
            ConversationStatePlugin(),
            ConversationPendingMessagePlugin(),
            ConversationForkPlugin(),
            ConversationExportPlugin(),
            AskUserPlugin(),
            OpenInFinderPlugin(),
            OpenInXcodePlugin(),
            OpenInCursorPlugin(),
            OpenInVSCodePlugin(),
            OpenInAntigravityPlugin(),
            OpenInGitHubDesktopPlugin(),
            OpenInGitOKPlugin(),
            AgentTurnNotificationPlugin(),
            // ACP Agent 端：GUI 下仅注册、不自启 stdio 服务（autoStartsServer=false），
            // 由 headless 入口（lumi-acp）解析该实例后显式启动。
            PluginACP(),
            DeveloperModePlugin(),
            FileLogPlugin(),
            ShowImagePlugin(),
            ImageToPDFPlugin(),
            DownloadPlugin(),
            AppManagerPlugin(),
            ClipboardManagerPlugin(),
            BrowserPlugin(),
            ComputerUsePlugin(),
            MCPPlugin(),
            PluginXcodeMCP(),
            PluginGithubMCP(),
            BrewManagerPlugin(),
            DisplayControlPlugin(),
            PortManagerPlugin(),
            DockerManagerPlugin(),
            RegistryManagerPlugin(),
            RClickPlugin(),
            InputPlugin(),
            BookletMakerPlugin(
                onWorkspaceActivate: { chatVisibility.activate() },
                onWorkspaceDeactivate: { chatVisibility.deactivate() }
            ),
            ScreenRecorderPlugin(),
            StoryWriterPlugin(),
            QuickFileSearchPlugin(),
            ProjectOverviewPlugin(),
            QuickLauncherPlugin(),
            TextActionsPlugin(),
            TerminalPlugin(),
            DatabaseManagerPlugin(),
            MailPlugin(),
            GitSourceControlPlugin(),
            GitRepositoryWatchPlugin(),
            GitWorkspacePlugin(),
            GoalTaskPlugin(),
            NettoPlugin(),
            SkillPlugin(),
            XcodeBuildPlugin(),
            OnboardingPlugin(),
            PluginWelcome(),
            MemoryPlugin(),
            ModelSelectorPlugin(),
            PluginMessageListEmptyPlugin(),
            PluginMessageListBriefPlugin(),
            PluginMessageListStandardPlugin(),
            PluginMessageListDetailedPlugin(),
            MessageRendererPlugin(),
            ConversationInputPlugin(),
            ConversationListPlugin(),
            ConversationNewPlugin(),
            ConversationManagerPlugin(),
            MessageManagerPlugin(),
            LLMContextPlugin(),
            PluginAgentLoop(),
            AgentLoopRetryPlugin(),
            MessageSenderPlugin(),
            PluginPluginManager(),
            // 设置视图管理器：替换 ProviderFactory 预注册的默认 SettingViewProviding 实现，
            // 必须先于各设置入口贡献插件（如 SettingGeneralPlugin order=200）。
            PluginSettingView(id: "com.coffic.lumi.plugin.setting-view"),
            PerformanceMetricsPlugin(),
            // Logo 管理器：替换 ProviderFactory 预注册的默认 LogoProviding 实现，
            // 必须先于各 Logo 贡献插件（如 LogoCofficPlugin order=100）。
            PluginLogoManager(),
            // LLM 供应商管理器：替换 ProviderFactory 预注册的默认实现，
            // 必须早于 PluginAgentLoop(order=8) 与各供应商插件(order=100)。
            PluginLLMManager(),
            // 工具管理器：替换默认 ToolManagerProviding 并注册内置工具，
            // 必须早于 PluginAgentLoop(order=8)。
            PluginToolManager(),
            ToolActivityPlugin(),
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
            CommandCodeProviderPlugin(),
            OpenRouterProviderPlugin(),
            StepFunProviderPlugin(),
            SublyxProviderPlugin(),
            TencentProviderPlugin(),
            XiaomiProviderPlugin(),
            XybbzProviderPlugin(),
            ZhipuProviderPlugin(),
            CodexLumiPlugin(),
            MLXProviderPlugin(),
            LLMProviderSettingsPlugin(),
        ]
        // UI 测试专用供应商（仅 DEBUG + --lumi-ui-testing 时才真正注册）。
        // 追加在数组末尾，保持 order=900 排在其他供应商之后，使其强制选中最后生效。
        //
        // - Important: PluginUITestProvider 的类体整体在 #if DEBUG 内，Release 构建中
        //   该类型不存在。Swift 不允许把 #if 直接内嵌在数组字面量中间，故先构造数组
        //   再条件追加；若裸写 PluginUITestProvider()，Release 报
        //   `cannot find 'PluginUITestProvider' in scope`。
        #if DEBUG
        plugins.append(PluginUITestProvider())
        #endif
        return plugins
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
