import LumiCoreKit
import DeviceInfoPlugin
import NetworkManagerPlugin
import ChatPanelPlugin
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
import LLMProviderCodexPlugin
import LLMProviderMLXPlugin
import AgentRAGPlugin
import AgentRulesPlugin
import MemoryPlugin
import RequestLogPlugin
import HistoryDBStatusBarPlugin
import SkillPlugin
import ConversationListPlugin
import ConversationTitlePlugin
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
import ThemeVscodeDarkPlugin
import ThemeRiverPlugin
import ThemeVscodeLightPlugin
import ThemeOneDarkPlugin
import ThemeDraculaPlugin
import ThemeStatusBarPlugin
import MultiAgentPlugin
import DatabaseManagerPlugin
import CodeReviewPlugin
import AgentDelayMessagePlugin
import AppIconDesignerPlugin
import EditorPanelPlugin
import EditorBreadcrumbNavPlugin
import EditorTabStripPlugin
import EditorStickySymbolBarPlugin
import EditorBottomProblemsPlugin
import EditorBottomReferencesPlugin
import EditorBottomSearchPlugin
import EditorBottomSymbolsPlugin
import EditorBottomCallHierarchyPlugin
import EditorPreviewPlugin
import EditorBottomTerminalPlugin
import EditorRailFileTreePlugin
import EditorOutlineRailPlugin
import EditorRailProblemsPlugin
import EditorRailReferencesPlugin
import EditorRailSearchPlugin
import EditorRailSymbolsPlugin
import EditorRailCallHierarchyPlugin
import LLMAvailabilityPlugin
import ConversationNewPlugin
import DisplayControlPlugin

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
        ThemeVscodeDarkPlugin.self,
        ThemeRiverPlugin.self,
        ThemeVscodeLightPlugin.self,
        ThemeOneDarkPlugin.self,
        ThemeDraculaPlugin.self,
        ThemeStatusBarPlugin.self,
        OnboardingPlugin.self,
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
        RAGPlugin.self,
        ConversationTitlePlugin.self,
        ConversationListPlugin.self,
        ConversationNewPlugin.self,
        EditorPanelPlugin.self,
        EditorBreadcrumbHeaderPlugin.self,
        EditorTabStripHeaderPlugin.self,
        EditorStickySymbolBarHeaderPlugin.self,
        EditorBottomProblemsPanelPlugin.self,
        EditorBottomReferencesPanelPlugin.self,
        EditorBottomSearchPanelPlugin.self,
        EditorBottomSymbolsPanelPlugin.self,
        EditorBottomCallHierarchyPanelPlugin.self,
        EditorPreviewBottomPanelPlugin.self,
        EditorBottomTerminalPanelPlugin.self,
        EditorRailFileTreePanelPlugin.self,
        EditorRailOutlinePanelPlugin.self,
        EditorRailProblemsPanelPlugin.self,
        EditorRailReferencesPanelPlugin.self,
        EditorRailSearchPanelPlugin.self,
        EditorRailSymbolsPanelPlugin.self,
        EditorRailCallHierarchyPanelPlugin.self,
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
        DisplayControlPlugin.self
    ]
}
