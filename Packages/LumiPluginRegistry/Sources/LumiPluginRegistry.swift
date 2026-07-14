import ActivityHeatmapPlugin
import AgentDelayMessagePlugin
import AgentRAGPlugin
import AgentRulesPlugin
import AgentTempStoragePlugin
import AgentTurnNotificationPlugin
import AppIconDesignerPlugin
import AppLoadedPluginsPlugin
import AppManagerPlugin
import AppStoreConnectPlugin
import AppUpdateStatusBarPlugin
import AskUserPlugin
import AutoTaskPlugin
import BrewManagerPlugin
import BrowserPlugin
import CADDesignerPlugin
import CaffeinatePlugin
import ChatModePlugin
import ChatPanelPlugin
import ClipboardManagerPlugin
import CodeReviewPlugin
import ConversationLanguagePlugin
import ConversationListPlugin
import ConversationNewPlugin
import ConversationForkPlugin
import ConversationTimelinePlugin
import ConversationTitlePlugin
import DatabaseManagerPlugin
import DeviceInfoPlugin
import DiskManagerPlugin
import DisplayControlPlugin
import DockerManagerPlugin
import DocxReadPlugin
import DownloadPlugin
import EditorBreadcrumbNavPlugin
import EditorCallHierarchyPlugin
import EditorFileTreePlugin
import EditorFileTreeV2Plugin
import EditorOutlinePlugin
import EditorPanelPlugin
import EditorPreviewPlugin
import EditorProblemsPlugin
import EditorReferencesPlugin
import EditorSearchPlugin
import EditorService
import EditorStickySymbolBarPlugin
import EditorSwiftPlugin
import EditorSymbolsPlugin
import EditorTabStripPlugin
import EditorTerminalPlugin
import FileLogPlugin
import FontConfigPlugin
import GitHubPlugin
import GitPlugin
import HistoryDBStatusBarPlugin
import HostsManagerPlugin
import IdleTimePlugin
import InputPlugin
import LayoutPlugin
import LLMProviderAiRouterPlugin
import LLMProviderAliyunPlugin
import LLMProviderAnthropicPlugin
import LLMProviderCodexPlugin
import LLMProviderDeepSeekPlugin
import LLMProviderFeifeimiaoPlugin
import LLMProviderFlyMuxPlugin
import LLMProviderFreeModelPlugin
import LLMProviderHappyCodePlugin
import LLMProviderHyperAPIPlugin
import LLMProviderLPgptPlugin
import LLMProviderMiniMaxPlugin
import LLMProviderMegaLLMPlugin
import LLMProviderMLXPlugin
import LLMProviderOpenAIPlugin
import LLMProviderOpenRouterPlugin
import LLMProviderStepFunPlugin
import LLMProviderSublyxPlugin
import LLMProviderXiaomiPlugin
import LLMProviderXybbzPlugin
import LLMProviderZhipuPlugin
import LogoCofficPlugin
import LogoSmartLightPlugin
import LumiCoreKit
import MemoryPlugin
import MenuBarManagerPlugin
import MessageListPlugin
import MessageRendererPlugin
import ModelSelectorPlugin
import MultiAgentPlugin
import NettoPlugin
import NetworkManagerPlugin
import OnboardingPlugin
import OpenInAntigravityPlugin
import OpenInCursorPlugin
import OpenInFinderPlugin
import OpenInGitHubDesktopPlugin
import OpenInGitOKPlugin
import OpenInXcodePlugin
import OpenRemotePlugin
import PortManagerPlugin
import ProjectIssueScannerPlugin
import ProjectOverviewPlugin
import ProjectsPlugin
import QuickFileSearchPlugin
import QuickLauncherPlugin
import RClickPlugin
import RegistryManagerPlugin
import RequestLogPlugin
import ShowImagePlugin
import SkillPlugin
import TerminalPlugin
import ThemeAuroraPlugin
import ThemeAutumnPlugin
import ThemeDraculaPlugin
import ThemeGithubPlugin
import ThemeLumiPlugin
import ThemeMidnightPlugin
import ThemeMountainPlugin
import ThemeNebulaPlugin
import ThemeOneDarkPlugin
import ThemeOrchardPlugin
import ThemeRiverPlugin
import ThemeSkyPlugin
import ThemeSpringPlugin
import ThemeStatusBarPlugin
import ThemeSummerPlugin
import ThemeVoidPlugin
import ThemeVscodePlugin
import ThemeWinterPlugin
import ToolCorePlugin
import VerbosityPlugin
import VideoConverterPlugin
import WebFetchPlugin
import WebSearchPlugin

@MainActor
public enum LumiPluginRegistry {
    /// 注册所有插件并触发 didRegister 生命周期事件
    public static func registerAll() async {
        for plugin in plugins {
            await plugin.lifecycle(.didRegister)
        }
    }

    /// 触发应用启动生命周期事件
    public static func appDidLaunch() async {
        for plugin in plugins {
            await plugin.lifecycle(.appDidLaunch)
        }
    }

    /// 在 app 启动早期、首帧渲染之前同步触发布局状态恢复。
    ///
    /// 背景：原本 `LayoutPlugin.lifecycle(.appDidLaunch)`（通过 `PluginService.init` 的异步 Task 触发）
    /// 会晚于 `AppLayoutView.onAppear` 执行，导致 `onAppear` 的默认选择先把 `containers[0]` 写入
    /// `activeViewContainerID` 并落盘，覆盖了磁盘里的持久化值。此入口让 restore 提前到
    /// `RootContainer.init` 同步阶段完成，确保首帧渲染前布局状态已是持久化值。
    ///
    /// restore 幂等：后续 `.appDidLaunch` 的二次调用为 no-op（普通属性 didSet 去重、divider 走无副作用的 restoreXxx）。
    @MainActor
    public static func restoreLayoutEarly() {
        LayoutPlugin.lifecycle(.appDidLaunch)
    }

    /// 触发项目打开生命周期事件
    public static func projectDidOpen(path: String) async {
        for plugin in plugins {
            await plugin.lifecycle(.projectDidOpen(path: path))
        }
    }

    /// 触发项目关闭生命周期事件
    public static func projectDidClose() async {
        for plugin in plugins {
            await plugin.lifecycle(.projectDidClose)
        }
    }

    public static let plugins: [any LumiPlugin.Type] = [
        // MARK: - Theme Plugins (from extension)

        themePlugins,

        // MARK: - Chat Plugins

        OnboardingPlugin.self,
        QuickFileSearchPlugin.self,
        QuickLauncherPlugin.self,
        AppUpdateStatusBarPlugin.self,
        DeviceInfoPlugin.self,
        NetworkManagerPlugin.self,
        HostsManagerPlugin.self,
        MenuBarManagerPlugin.self,
        ChatPanelPlugin.self,
        MessageListPlugin.self,
        ChatAttachmentSectionPlugin.self,
        ChatPendingSectionPlugin.self,
        ChatComposerSectionPlugin.self,
        ModelSelectorPlugin.self,

        // MARK: - LLM Providers

        OpenAIPlugin.self,
        ZhipuPlugin.self,
        AiRouterPlugin.self,
        AliyunPlugin.self,
        AnthropicPlugin.self,
        DeepSeekPlugin.self,
        FeifeimiaoPlugin.self,
        FlyMuxPlugin.self,
        FreeModelPlugin.self,
        HappyCodePlugin.self,
        HyperAPIPlugin.self,
        LPgptPlugin.self,
        MegaLLMPlugin.self,
        MiniMaxPlugin.self,
        OpenRouterPlugin.self,
        XiaomiPlugin.self,
        XybbzPlugin.self,
        SublyxPlugin.self,
        StepFunPlugin.self,
        CodexLumiPlugin.self,
        MLXLumiPlugin.self,

        // MARK: - Open In Plugins

        AgentOpenInAntigravityPlugin.self,
        AgentOpenInCursorPlugin.self,
        AgentOpenInXcodePlugin.self,
        AgentOpenRemotePlugin.self,
        AgentOpenInGitHubDesktopPlugin.self,
        AgentOpenInFinderPlugin.self,
        AgentOpenInGitOKPlugin.self,

        TerminalPlugin.self,
        FontConfigPlugin.self,
        AppLoadedPluginsPlugin.self,
        ToolCorePlugin.self,
        MessageRendererPlugin.self,
        MemoryPlugin.self,
        AgentRulesPlugin.self,
        SkillPlugin.self,
        RequestLogPlugin.self,
        HistoryDBStatusBarPlugin.self,
        ActivityHeatmapPlugin.self,
        RAGPlugin.self,
        AgentTempStoragePlugin.self,

        // MARK: - Conversation Plugins

        ConversationTitlePlugin.self,
        ConversationTimelinePlugin.self,
        ConversationLanguagePlugin.self,
        ChatModePlugin.self,
        VerbosityPlugin.self,
        ConversationListPlugin.self,
        ConversationNewPlugin.self,
        ConversationForkPlugin.self,

        // MARK: - Editor Plugins (from extension)

        editorPlugins,

        // MARK: - Logo Plugins

        LogoSmartLightPlugin.self,
        LogoCofficPlugin.self,

        // MARK: - Others

        VideoConverterPlugin.self,
        DownloadPlugin.self,
        DocxReadPlugin.self,
        PortManagerPlugin.self,
        AppManagerPlugin.self,
        DockerManagerPlugin.self,
        DiskManagerPlugin.self,
        AppStoreConnectPlugin.self,
        BrewManagerPlugin.self,
        RClickPlugin.self,
        NettoPlugin.self,
        RegistryManagerPlugin.self,
        ClipboardManagerPlugin.self,
        InputPlugin.self,
    ]
}
