import LumiCoreKit
import DeviceInfoPlugin
import NetworkManagerPlugin
import ChatPanelPlugin
import ModelSelectorPlugin
import MessageListPlugin
import LLMProviderOpenAIPlugin
import LLMProviderZhipuPlugin
import LLMProviderAiRouterPlugin
import LLMProviderAliyunPlugin
import LLMProviderAnthropicPlugin
import LLMProviderDeepSeekPlugin
import LLMProviderFeifeimiaoPlugin
import LLMProviderFlyMuxPlugin
import LLMProviderFreeModelPlugin
import LLMProviderHappyCodePlugin
import LLMProviderHyperAPIPlugin
import LLMProviderLPgptPlugin
import LLMProviderMegaLLMPlugin
import LLMProviderOpenRouterPlugin
import LLMProviderXiaomiPlugin
import LLMProviderXybbzPlugin
import LLMProviderSublyxPlugin
import LLMProviderCodexPlugin
import LLMProviderMLXPlugin
import AgentRAGPlugin
import AgentTempStoragePlugin
import AgentRulesPlugin
import MemoryPlugin
import RequestLogPlugin
import HistoryDBStatusBarPlugin
import ActivityHeatmapPlugin
import SkillPlugin
import ConversationListPlugin
import ConversationTitlePlugin
import ConversationTimelinePlugin
import ConversationLanguagePlugin
import ChatModePlugin
import VerbosityPlugin
import AutoTaskPlugin
import GitHubPlugin
import IdleTimePlugin
import ProjectIssueScannerPlugin
import ProjectsPlugin
import WebSearchPlugin
import WebFetchPlugin
import GitPlugin
import AskUserPlugin
import CaffeinatePlugin
import BrowserPlugin
import ProjectOverviewPlugin
import ShowImagePlugin
import AppManagerPlugin
import DiskManagerPlugin
import PortManagerPlugin
import DockerManagerPlugin
import BrewManagerPlugin
import ClipboardManagerPlugin
import HostsManagerPlugin
import InputPlugin
import NettoPlugin
import RClickPlugin
import RegistryManagerPlugin
import AppStoreConnectPlugin
import TerminalPlugin
import MenuBarManagerPlugin
import QuickFileSearchPlugin
import QuickLauncherPlugin
import AppUpdateStatusBarPlugin
import AppLoadedPluginsPlugin
import FontConfigPlugin
import OpenInCursorPlugin
import OpenInXcodePlugin
import OpenInFinderPlugin
import OpenInGitOKPlugin
import OpenInGitHubDesktopPlugin
import OpenInAntigravityPlugin
import OpenRemotePlugin
import LayoutPlugin
import OnboardingPlugin
import AgentTurnNotificationPlugin
import FileLogPlugin
import ToolCorePlugin
import MessageRendererPlugin
import ThemeLumiPlugin
import ThemeMidnightPlugin
import ThemeSkyPlugin
import ThemeAuroraPlugin
import ThemeNebulaPlugin
import ThemeVoidPlugin
import ThemeSpringPlugin
import ThemeSummerPlugin
import ThemeAutumnPlugin
import ThemeWinterPlugin
import ThemeGithubPlugin
import ThemeOrchardPlugin
import ThemeMountainPlugin
import ThemeVscodePlugin
import ThemeRiverPlugin
import ThemeOneDarkPlugin
import ThemeDraculaPlugin
import ThemeStatusBarPlugin
import MultiAgentPlugin
import DatabaseManagerPlugin
import CodeReviewPlugin
import AgentDelayMessagePlugin
import AppIconDesignerPlugin
import EditorPanelPlugin
import EditorSwiftPlugin
import EditorBreadcrumbNavPlugin
import EditorTabStripPlugin
import EditorStickySymbolBarPlugin
import EditorProblemsPlugin
import EditorReferencesPlugin
import EditorSearchPlugin
import EditorSymbolsPlugin
import EditorCallHierarchyPlugin
import EditorPreviewPlugin
import EditorTerminalPlugin
import EditorFileTreePlugin
import EditorOutlinePlugin
import LLMAvailabilityPlugin
import ConversationNewPlugin
import DisplayControlPlugin
import LogoSmartLightPlugin
import LogoCofficPlugin
import VideoConverterPlugin
import DownloadPlugin

@MainActor
public enum LumiPluginRegistry {
    public static let plugins: [any LumiPlugin.Type] = [
        FileLogPlugin.self,
        LayoutPlugin.self,
        ThemeLumiPlugin.self,
        ThemeMidnightPlugin.self,
        ThemeSkyPlugin.self,
        ThemeAuroraPlugin.self,
        ThemeNebulaPlugin.self,
        ThemeVoidPlugin.self,
        ThemeSpringPlugin.self,
        ThemeSummerPlugin.self,
        ThemeAutumnPlugin.self,
        ThemeWinterPlugin.self,
        ThemeGithubPlugin.self,
        ThemeOrchardPlugin.self,
        ThemeMountainPlugin.self,
        ThemeVscodePlugin.self,
        ThemeRiverPlugin.self,
        ThemeOneDarkPlugin.self,
        ThemeDraculaPlugin.self,
        ThemeStatusBarPlugin.self,
        OnboardingPlugin.self,
        QuickFileSearchPlugin.self,
        QuickLauncherPlugin.self,
        AppUpdateStatusBarPlugin.self,
        DeviceInfoPlugin.self,
        NetworkManagerPlugin.self,
        HostsManagerPlugin.self,
        MenuBarManagerPlugin.self,
        ChatPanelPlugin.self,
        ChatMessagesSectionPlugin.self,
        ChatAttachmentSectionPlugin.self,
        ChatPendingSectionPlugin.self,
        ChatComposerSectionPlugin.self,
        ModelSelectorPlugin.self,
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
        OpenRouterPlugin.self,
        XiaomiPlugin.self,
        XybbzPlugin.self,
        SublyxPlugin.self,
        CodexLumiPlugin.self,
        MLXLumiPlugin.self,
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
        ConversationTitlePlugin.self,
        ConversationTimelinePlugin.self,
        ConversationLanguagePlugin.self,
        ChatModePlugin.self,
        VerbosityPlugin.self,
        ConversationListPlugin.self,
        ConversationNewPlugin.self,
        EditorPanelPlugin.self,
        EditorSwiftPlugin.self,
        EditorBreadcrumbHeaderPlugin.self,
        StripHeaderPlugin.self,
        EditorStickySymbolBarHeaderPlugin.self,
        EditorProblemsPanelPlugin.self,
        EditorReferencesPanelPlugin.self,
        EditorSearchPanelPlugin.self,
        EditorSymbolsPanelPlugin.self,
        EditorCallHierarchyPanelPlugin.self,
        EditorPreviewBottomPanelPlugin.self,
        EditorTerminalPanelPlugin.self,
        EditorFileTreePanelPlugin.self,
        EditorOutlinePanelPlugin.self,
        AutoTaskPlugin.self,
        GitHubPlugin.self,
        IdleTimePlugin.self,
        ProjectIssueScannerPlugin.self,
        AgentTurnNotificationPlugin.self,
        ProjectsPlugin.self,
        WebSearchPlugin.self,
        WebFetchPlugin.self,
        GitPlugin.self,
        AskUserPlugin.self,
        CaffeinatePlugin.self,
        BrowserPlugin.self,
        ProjectOverviewPlugin.self,
        ShowImagePlugin.self,
        MultiAgentPlugin.self,
        DatabaseManagerPlugin.self,
        CodeReviewPlugin.self,
        DelayMessagePlugin.self,
        LLMAvailabilityPlugin.self,
        AppIconDesignerPlugin.self,
        DisplayControlPlugin.self,
        LogoSmartLightPlugin.self,
        LogoCofficPlugin.self,
        VideoConverterPlugin.self,
        DownloadPlugin.self,
    ]
}
