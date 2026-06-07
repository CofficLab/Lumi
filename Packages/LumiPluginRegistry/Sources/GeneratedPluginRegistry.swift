import LumiCoreKit
import ToolAvailablePlugin
import ToolCorePlugin
import AgentDelayMessagePlugin
import AgentGitHubToolsPlugin
import ConversationLanguagePlugin
import AgentMCPToolsPlugin
import MessageRendererPlugin
import SendQueuePlugin
import MessageSenderPlugin
import TurnLifecyclePlugin
import ToolExecutorPlugin
import AgentRAGPlugin
import AgentRulesPlugin
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
import CSSEditorPlugin
import CaffeinatePlugin
import ChatAttachmentPlugin
import ChatInputPlugin
import MessageListPlugin
import ChatModePlugin
import ChatPanelPlugin
import ChatPendingMessagesPlugin
import ChatSubmitPlugin
import ClipboardManagerPlugin
import CodeReviewPlugin
import ConversationListPlugin
import ConversationNewPlugin
import ConversationTimelinePlugin
import ConversationTitlePlugin
import DatabaseManagerPlugin
import DeviceInfoPlugin
import DiskManagerPlugin
import DockerManagerPlugin
import EditorBottomCallHierarchyPlugin
import EditorBottomProblemsPlugin
import EditorBottomReferencesPlugin
import EditorBottomSearchPlugin
import EditorBottomSymbolsPlugin
import EditorBottomTerminalPlugin
import EditorBreadcrumbPlugin
import EditorCallHierarchyRailPlugin
import EditorChatIntegrationPlugin
import EditorLSPContextCommandsPlugin
import EditorOutlineRailPlugin
import EditorPanelPlugin
import EditorPreviewPlugin
import EditorRailFileTreePlugin
import EditorRailProblemsPlugin
import EditorRailReferencesPlugin
import EditorRailWorkspaceSearchPlugin
import EditorRailWorkspaceSymbolsPlugin
import EditorStickySymbolBarPlugin
import EditorSwiftKeywordHoverPlugin
import EditorTabStripPlugin
import EditorXcodePlugin
import FileLogPlugin
import FontConfigPlugin
import GitPlugin
import GitHubCLIDetectPlugin
import GitHubInsightPlugin
import GoEditorPlugin
import HTMLEditorPlugin
import HistoryDBStatusBarPlugin
import HostsManagerPlugin
import IdleTimePlugin
import InputPlugin
import JSEditorPlugin
import LLMAvailabilityPlugin
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
import LLMProviderMLXPlugin
import LLMProviderMegaLLMPlugin
import LLMProviderOpenAIPlugin
import LLMProviderOpenRouterPlugin
import LLMProviderXiaomiPlugin
import LLMProviderXybbzPlugin
import LLMProviderZhipuPlugin
import LSPCallHierarchyEditorPlugin
import LSPCodeActionEditorPlugin
import LSPDocumentColorEditorPlugin
import LSPDocumentHighlightEditorPlugin
import LSPDocumentLinkEditorPlugin
import LSPFoldingRangeEditorPlugin
import LSPInlayHintEditorPlugin
import LSPRealtimeSignalsEditorPlugin
import LSPSelectionRangeEditorPlugin
import LSPServiceEditorPlugin
import LSPSheetsEditorPlugin
import LSPSignatureHelpEditorPlugin
import LSPToolbarEditorPlugin
import LSPWorkspaceSymbolEditorPlugin
import LayoutPlugin
import MarkdownEditorPlugin
import MemoryPlugin
import MenuBarManagerPlugin
import ModelPreferencePlugin
import ModelSelectorPlugin
import MultiAgentPlugin
import EditorMultiCursorCommandsPlugin
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
import SampleDecorationEditorPlugin
import ScreenshotPlugin
import ShowImagePlugin
import SkillPlugin
import SwiftPrimitiveTypesEditorPlugin
import SwiftSelectionCodeActionEditorPlugin
import TerminalPlugin
import TextActionsPlugin
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
import ThemeVscodeDarkPlugin
import ThemeVscodeLightPlugin
import ThemeWinterPlugin
import ToolCallLoopDetectionPlugin
import VerbosityPlugin
import VueEditorPlugin
import WebFetchPlugin
import WebSearchPlugin
import WindowPersistencePlugin

/// Central plugin registry.
///
/// Add packaged plugins here explicitly when they should be available to Lumi.
public enum GeneratedPluginRegistry {
    @MainActor
    public static var plugins: [any LumiCoreKit.SuperPlugin] {
        var plugins: [any LumiCoreKit.SuperPlugin] = []
        plugins.append(ToolAvailablePlugin.shared)
        plugins.append(ToolCorePlugin.shared)
        plugins.append(DelayMessagePlugin.shared)
        plugins.append(GitHubToolsPlugin.shared)
        plugins.append(ConversationLanguagePlugin.shared)
        plugins.append(AgentMCPToolsPlugin.shared)
        plugins.append(MessageRendererPlugin.shared)
        plugins.append(SendQueuePlugin.shared)
        plugins.append(MessageSenderPlugin.shared)
        plugins.append(TurnLifecyclePlugin.shared)
        plugins.append(ToolExecutorPlugin.shared)
        plugins.append(RAGPlugin.shared)
        plugins.append(AgentRulesPlugin.shared)
        plugins.append(AgentTurnNotificationPlugin.shared)
        plugins.append(AppIconDesignerPlugin.shared)
        plugins.append(AppLoadedPluginsPlugin.shared)
        plugins.append(AppManagerPlugin.shared)
        plugins.append(AppStoreConnectPlugin.shared)
        plugins.append(AppUpdateStatusBarPlugin.shared)
        plugins.append(AskUserPlugin.shared)
        plugins.append(AutoTaskPlugin.shared)
        plugins.append(BrewManagerPlugin.shared)
        plugins.append(BrowserPlugin.shared)
        plugins.append(CSSEditorPlugin.shared)
        plugins.append(CaffeinatePlugin.shared)
        plugins.append(ChatAttachmentPlugin.shared)
        plugins.append(ChatInputPlugin.shared)
        plugins.append(AgentChatPlugin.shared)
        plugins.append(ChatModePlugin.shared)
        plugins.append(ChatPanelPlugin.shared)
        plugins.append(ChatPendingMessagesPlugin.shared)
        plugins.append(ChatSubmitPlugin.shared)
        plugins.append(ClipboardManagerPlugin.shared)
        plugins.append(CodeReviewPlugin.shared)
        plugins.append(ConversationListPlugin.shared)
        plugins.append(ConversationNewPlugin.shared)
        plugins.append(ConversationTimelinePlugin.shared)
        plugins.append(ConversationTitlePlugin.shared)
        plugins.append(DatabaseManagerPlugin.shared)
        plugins.append(DeviceInfoPlugin.shared)
        plugins.append(DiskManagerPlugin.shared)
        plugins.append(DockerManagerPlugin.shared)
        plugins.append(EditorBottomCallHierarchyPlugin.shared)
        plugins.append(EditorBottomProblemsPlugin.shared)
        plugins.append(EditorBottomReferencesPlugin.shared)
        plugins.append(EditorBottomSearchPlugin.shared)
        plugins.append(EditorBottomSymbolsPlugin.shared)
        plugins.append(EditorBottomTerminalPlugin.shared)
        plugins.append(BreadcrumbNavPlugin.shared)
        plugins.append(EditorCallHierarchyRailPlugin.shared)
        plugins.append(EditorChatIntegrationPlugin.shared)
        plugins.append(EditorLSPContextCommandsPlugin.shared)
        plugins.append(EditorOutlineRailPlugin.shared)
        plugins.append(EditorPlugin.shared)
        plugins.append(EditorPreviewPlugin.shared)
        plugins.append(EditorRailFileTreePlugin.shared)
        plugins.append(EditorRailProblemsPlugin.shared)
        plugins.append(EditorRailReferencesPlugin.shared)
        plugins.append(EditorRailWorkspaceSearchPlugin.shared)
        plugins.append(EditorRailWorkspaceSymbolsPlugin.shared)
        plugins.append(EditorStickySymbolBarPlugin.shared)
        plugins.append(EditorSwiftKeywordHoverPlugin.shared)
        plugins.append(EditorTabStripPlugin.shared)
        plugins.append(EditorXcodePlugin.shared)
        plugins.append(FileLogPlugin.shared)
        plugins.append(FontConfigPlugin.shared)
        plugins.append(GitPlugin.shared)
        plugins.append(GitHubCLIDetectPlugin.shared)
        plugins.append(GitHubInsightPlugin.shared)
        plugins.append(GoEditorPlugin.shared)
        plugins.append(HTMLEditorPlugin.shared)
        plugins.append(HistoryDBStatusBarPlugin.shared)
        plugins.append(HostsManagerPlugin.shared)
        plugins.append(IdleTimePlugin.shared)
        plugins.append(InputPlugin.shared)
        plugins.append(JSEditorPlugin.shared)
        plugins.append(LLMAvailabilityPlugin.shared)
        plugins.append(AiRouterPlugin.shared)
        plugins.append(AliyunPlugin.shared)
        plugins.append(AnthropicPlugin.shared)
        plugins.append(CodexPlugin.shared)
        plugins.append(DeepSeekPlugin.shared)
        plugins.append(FeifeimiaoPlugin.shared)
        plugins.append(FlyMuxPlugin.shared)
        plugins.append(FreeModelPlugin.shared)
        plugins.append(HappyCodePlugin.shared)
        plugins.append(HyperAPIPlugin.shared)
        plugins.append(LPgptPlugin.shared)
        plugins.append(MLXPlugin.shared)
        plugins.append(MegaLLMPlugin.shared)
        plugins.append(OpenAIPlugin.shared)
        plugins.append(OpenRouterPlugin.shared)
        plugins.append(XiaomiPlugin.shared)
        plugins.append(XybbzPlugin.shared)
        plugins.append(ZhipuPlugin.shared)
        plugins.append(LSPCallHierarchyEditorPlugin.shared)
        plugins.append(LSPCodeActionEditorPlugin.shared)
        plugins.append(LSPDocumentColorEditorPlugin.shared)
        plugins.append(LSPDocumentHighlightEditorPlugin.shared)
        plugins.append(LSPDocumentLinkEditorPlugin.shared)
        plugins.append(LSPFoldingRangeEditorPlugin.shared)
        plugins.append(LSPInlayHintEditorPlugin.shared)
        plugins.append(LSPRealtimeSignalsEditorPlugin.shared)
        plugins.append(LSPSelectionRangeEditorPlugin.shared)
        plugins.append(LSPServiceEditorPlugin.shared)
        plugins.append(LSPSheetsEditorPlugin.shared)
        plugins.append(LSPSignatureHelpEditorPlugin.shared)
        plugins.append(LSPToolbarEditorPlugin.shared)
        plugins.append(LSPWorkspaceSymbolEditorPlugin.shared)
        plugins.append(LayoutPlugin.shared)
        plugins.append(MarkdownEditorPlugin.shared)
        plugins.append(MemoryPlugin.shared)
        plugins.append(MenuBarManagerPlugin.shared)
        plugins.append(ModelPreferencePlugin.shared)
        plugins.append(ModelSelectorPlugin.shared)
        plugins.append(MultiAgentPlugin.shared)
        plugins.append(EditorMultiCursorCommandsPlugin.shared)
        plugins.append(NettoPlugin.shared)
        plugins.append(NetworkManagerPlugin.shared)
        plugins.append(OnboardingPlugin.shared)
        plugins.append(AgentOpenInAntigravityPlugin.shared)
        plugins.append(AgentOpenInCursorPlugin.shared)
        plugins.append(AgentOpenInFinderPlugin.shared)
        plugins.append(AgentOpenInGitHubDesktopPlugin.shared)
        plugins.append(AgentOpenInGitOKPlugin.shared)
        plugins.append(AgentOpenInXcodePlugin.shared)
        plugins.append(AgentOpenRemotePlugin.shared)
        plugins.append(PortManagerPlugin.shared)
        plugins.append(ProjectIssueScannerPlugin.shared)
        plugins.append(ProjectOverviewPlugin.shared)
        plugins.append(ProjectsPlugin.shared)
        plugins.append(QuickFileSearchPlugin.shared)
        plugins.append(QuickLauncherPlugin.shared)
        plugins.append(RClickPlugin.shared)
        plugins.append(RegistryManagerPlugin.shared)
        plugins.append(RequestLogPlugin.shared)
        plugins.append(SampleDecorationEditorPlugin.shared)
        plugins.append(ScreenshotPlugin.shared)
        plugins.append(ShowImagePlugin.shared)
        plugins.append(SkillPlugin.shared)
        plugins.append(SwiftPrimitiveTypesEditorPlugin.shared)
        plugins.append(SwiftSelectionCodeActionEditorPlugin.shared)
        plugins.append(TerminalPlugin.shared)
        plugins.append(TextActionsPlugin.shared)
        plugins.append(ThemeAuroraPlugin.shared)
        plugins.append(ThemeAutumnPlugin.shared)
        plugins.append(ThemeDraculaPlugin.shared)
        plugins.append(ThemeGithubPlugin.shared)
        plugins.append(ThemeLumiPlugin.shared)
        plugins.append(ThemeMidnightPlugin.shared)
        plugins.append(ThemeMountainPlugin.shared)
        plugins.append(ThemeNebulaPlugin.shared)
        plugins.append(ThemeOneDarkPlugin.shared)
        plugins.append(ThemeOrchardPlugin.shared)
        plugins.append(ThemeRiverPlugin.shared)
        plugins.append(ThemeSkyPlugin.shared)
        plugins.append(ThemeSpringPlugin.shared)
        plugins.append(ThemeStatusBarPlugin.shared)
        plugins.append(ThemeSummerPlugin.shared)
        plugins.append(ThemeVoidPlugin.shared)
        plugins.append(ThemeVscodeDarkPlugin.shared)
        plugins.append(ThemeVscodeLightPlugin.shared)
        plugins.append(ThemeWinterPlugin.shared)
        plugins.append(ToolCallLoopDetectionPlugin.shared)
        plugins.append(VerbosityPlugin.shared)
        plugins.append(VueEditorPlugin.shared)
        plugins.append(WebFetchPlugin.shared)
        plugins.append(WebSearchPlugin.shared)
        plugins.append(WindowPersistencePlugin.shared)
        return plugins
    }
}
