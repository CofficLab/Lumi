import LumiCoreKit
import AgentAvailableToolsPlugin
import AgentContextSyncPlugin
import AgentCoreToolsPlugin
import AgentDelayMessagePlugin
import AgentGitHubToolsPlugin
import AgentLanguagePlugin
import AgentMCPToolsPlugin
import AgentMessageRendererPlugin
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
import BrowserAgentPlugin
import CSSEditorPlugin
import CaffeinatePlugin
import ChatAttachmentPlugin
import ChatInputPlugin
import ChatMessagesPlugin
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
import MultiCursorCommandsEditorPlugin
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
import SampleInsightsEditorPlugin
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
import ToolPermissionPlugin
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
        plugins.append(AgentAvailableToolsPlugin.AgentAvailableToolsPlugin.shared)
        plugins.append(AgentContextSyncPlugin.AgentContextSyncPlugin.shared)
        plugins.append(AgentCoreToolsPlugin.AgentCoreToolsPlugin.shared)
        plugins.append(AgentDelayMessagePlugin.DelayMessagePlugin.shared)
        plugins.append(AgentGitHubToolsPlugin.GitHubToolsPlugin.shared)
        plugins.append(AgentLanguagePlugin.AgentLanguagePlugin.shared)
        plugins.append(AgentMCPToolsPlugin.AgentMCPToolsPlugin.shared)
        plugins.append(AgentMessageRendererPlugin.MessageRendererPlugin.shared)
        plugins.append(AgentRAGPlugin.RAGPlugin.shared)
        plugins.append(AgentRulesPlugin.AgentRulesPlugin.shared)
        plugins.append(AgentTurnNotificationPlugin.AgentTurnNotificationPlugin.shared)
        plugins.append(AppIconDesignerPlugin.AppIconDesignerPlugin.shared)
        plugins.append(AppLoadedPluginsPlugin.AppLoadedPluginsPlugin.shared)
        plugins.append(AppManagerPlugin.AppManagerPlugin.shared)
        plugins.append(AppStoreConnectPlugin.AppStoreConnectPlugin.shared)
        plugins.append(AppUpdateStatusBarPlugin.AppUpdateStatusBarPlugin.shared)
        plugins.append(AskUserPlugin.AskUserPlugin.shared)
        plugins.append(AutoTaskPlugin.AutoTaskPlugin.shared)
        plugins.append(BrewManagerPlugin.BrewManagerPlugin.shared)
        plugins.append(BrowserPlugin.BrowserPlugin.shared)
        plugins.append(BrowserAgentPlugin.BrowserAgentPlugin.shared)
        plugins.append(CSSEditorPlugin.CSSEditorPlugin.shared)
        plugins.append(CaffeinatePlugin.CaffeinatePlugin.shared)
        plugins.append(ChatAttachmentPlugin.ChatAttachmentPlugin.shared)
        plugins.append(ChatInputPlugin.ChatInputPlugin.shared)
        plugins.append(ChatMessagesPlugin.AgentChatPlugin.shared)
        plugins.append(ChatModePlugin.ChatModePlugin.shared)
        plugins.append(ChatPanelPlugin.ChatPanelPlugin.shared)
        plugins.append(ChatPendingMessagesPlugin.ChatPendingMessagesPlugin.shared)
        plugins.append(ChatSubmitPlugin.ChatSubmitPlugin.shared)
        plugins.append(ClipboardManagerPlugin.ClipboardManagerPlugin.shared)
        plugins.append(CodeReviewPlugin.CodeReviewPlugin.shared)
        plugins.append(ConversationListPlugin.ConversationListPlugin.shared)
        plugins.append(ConversationNewPlugin.ConversationNewHeaderPlugin.shared)
        plugins.append(ConversationTimelinePlugin.ConversationTimelinePlugin.shared)
        plugins.append(ConversationTitlePlugin.ConversationTitlePlugin.shared)
        plugins.append(DatabaseManagerPlugin.DatabaseManagerPlugin.shared)
        plugins.append(DeviceInfoPlugin.DeviceInfoPlugin.shared)
        plugins.append(DiskManagerPlugin.DiskManagerPlugin.shared)
        plugins.append(DockerManagerPlugin.DockerManagerPlugin.shared)
        plugins.append(EditorBottomCallHierarchyPlugin.EditorBottomCallHierarchyPlugin.shared)
        plugins.append(EditorBottomProblemsPlugin.EditorBottomProblemsPlugin.shared)
        plugins.append(EditorBottomReferencesPlugin.EditorBottomReferencesPlugin.shared)
        plugins.append(EditorBottomSearchPlugin.EditorBottomSearchPlugin.shared)
        plugins.append(EditorBottomSymbolsPlugin.EditorBottomSymbolsPlugin.shared)
        plugins.append(EditorBottomTerminalPlugin.EditorBottomTerminalPlugin.shared)
        plugins.append(EditorBreadcrumbPlugin.BreadcrumbNavPlugin.shared)
        plugins.append(EditorCallHierarchyRailPlugin.EditorCallHierarchyRailPlugin.shared)
        plugins.append(EditorChatIntegrationPlugin.EditorChatIntegrationPlugin.shared)
        plugins.append(EditorLSPContextCommandsPlugin.EditorLSPContextCommandsPlugin.shared)
        plugins.append(EditorOutlineRailPlugin.EditorOutlineRailPlugin.shared)
        plugins.append(EditorPanelPlugin.EditorPlugin.shared)
        plugins.append(EditorPreviewPlugin.EditorPreviewPlugin.shared)
        plugins.append(EditorRailFileTreePlugin.EditorRailFileTreePlugin.shared)
        plugins.append(EditorRailProblemsPlugin.EditorRailProblemsPlugin.shared)
        plugins.append(EditorRailReferencesPlugin.EditorRailReferencesPlugin.shared)
        plugins.append(EditorRailWorkspaceSearchPlugin.EditorRailWorkspaceSearchPlugin.shared)
        plugins.append(EditorRailWorkspaceSymbolsPlugin.EditorRailWorkspaceSymbolsPlugin.shared)
        plugins.append(EditorStickySymbolBarPlugin.EditorStickySymbolBarPlugin.shared)
        plugins.append(EditorSwiftKeywordHoverPlugin.EditorSwiftKeywordHoverPlugin.shared)
        plugins.append(EditorTabStripPlugin.EditorTabStripPlugin.shared)
        plugins.append(EditorXcodePlugin.EditorXcodePlugin.shared)
        plugins.append(FileLogPlugin.FileLogPlugin.shared)
        plugins.append(FontConfigPlugin.FontConfigPlugin.shared)
        plugins.append(GitPlugin.GitPlugin.shared)
        plugins.append(GitHubCLIDetectPlugin.GitHubCLIDetectPlugin.shared)
        plugins.append(GitHubInsightPlugin.GitHubInsightPlugin.shared)
        plugins.append(GoEditorPlugin.GoEditorPlugin.shared)
        plugins.append(HTMLEditorPlugin.HTMLEditorPlugin.shared)
        plugins.append(HistoryDBStatusBarPlugin.HistoryDBStatusBarPlugin.shared)
        plugins.append(HostsManagerPlugin.HostsManagerPlugin.shared)
        plugins.append(IdleTimePlugin.IdleTimePlugin.shared)
        plugins.append(InputPlugin.InputPlugin.shared)
        plugins.append(JSEditorPlugin.JSEditorPlugin.shared)
        plugins.append(LLMAvailabilityPlugin.LLMAvailabilityPlugin.shared)
        plugins.append(LLMProviderAiRouterPlugin.AiRouterPlugin.shared)
        plugins.append(LLMProviderAliyunPlugin.AliyunPlugin.shared)
        plugins.append(LLMProviderAnthropicPlugin.AnthropicPlugin.shared)
        plugins.append(LLMProviderCodexPlugin.CodexPlugin.shared)
        plugins.append(LLMProviderDeepSeekPlugin.DeepSeekPlugin.shared)
        plugins.append(LLMProviderFeifeimiaoPlugin.FeifeimiaoPlugin.shared)
        plugins.append(LLMProviderFlyMuxPlugin.FlyMuxPlugin.shared)
        plugins.append(LLMProviderFreeModelPlugin.FreeModelPlugin.shared)
        plugins.append(LLMProviderHappyCodePlugin.HappyCodePlugin.shared)
        plugins.append(LLMProviderHyperAPIPlugin.HyperAPIPlugin.shared)
        plugins.append(LLMProviderLPgptPlugin.LPgptPlugin.shared)
        plugins.append(LLMProviderMLXPlugin.MLXPlugin.shared)
        plugins.append(LLMProviderMegaLLMPlugin.MegaLLMPlugin.shared)
        plugins.append(LLMProviderOpenAIPlugin.OpenAIPlugin.shared)
        plugins.append(LLMProviderOpenRouterPlugin.OpenRouterPlugin.shared)
        plugins.append(LLMProviderXiaomiPlugin.XiaomiPlugin.shared)
        plugins.append(LLMProviderXybbzPlugin.XybbzPlugin.shared)
        plugins.append(LLMProviderZhipuPlugin.ZhipuPlugin.shared)
        plugins.append(LSPCallHierarchyEditorPlugin.LSPCallHierarchyEditorPlugin.shared)
        plugins.append(LSPCodeActionEditorPlugin.LSPCodeActionEditorPlugin.shared)
        plugins.append(LSPDocumentColorEditorPlugin.LSPDocumentColorEditorPlugin.shared)
        plugins.append(LSPDocumentHighlightEditorPlugin.LSPDocumentHighlightEditorPlugin.shared)
        plugins.append(LSPDocumentLinkEditorPlugin.LSPDocumentLinkEditorPlugin.shared)
        plugins.append(LSPFoldingRangeEditorPlugin.LSPFoldingRangeEditorPlugin.shared)
        plugins.append(LSPInlayHintEditorPlugin.LSPInlayHintEditorPlugin.shared)
        plugins.append(LSPRealtimeSignalsEditorPlugin.LSPRealtimeSignalsEditorPlugin.shared)
        plugins.append(LSPSelectionRangeEditorPlugin.LSPSelectionRangeEditorPlugin.shared)
        plugins.append(LSPServiceEditorPlugin.LSPServiceEditorPlugin.shared)
        plugins.append(LSPSheetsEditorPlugin.LSPSheetsEditorPlugin.shared)
        plugins.append(LSPSignatureHelpEditorPlugin.LSPSignatureHelpEditorPlugin.shared)
        plugins.append(LSPToolbarEditorPlugin.LSPToolbarEditorPlugin.shared)
        plugins.append(LSPWorkspaceSymbolEditorPlugin.LSPWorkspaceSymbolEditorPlugin.shared)
        plugins.append(LayoutPlugin.LayoutPlugin.shared)
        plugins.append(MarkdownEditorPlugin.MarkdownEditorPlugin.shared)
        plugins.append(MemoryPlugin.MemoryPlugin.shared)
        plugins.append(MenuBarManagerPlugin.MenuBarManagerPlugin.shared)
        plugins.append(ModelPreferencePlugin.ModelPreferencePlugin.shared)
        plugins.append(ModelSelectorPlugin.ModelSelectorPlugin.shared)
        plugins.append(MultiAgentPlugin.MultiAgentPlugin.shared)
        plugins.append(MultiCursorCommandsEditorPlugin.MultiCursorCommandsEditorPlugin.shared)
        plugins.append(NettoPlugin.NettoPlugin.shared)
        plugins.append(NetworkManagerPlugin.NetworkManagerPlugin.shared)
        plugins.append(OnboardingPlugin.OnboardingPlugin.shared)
        plugins.append(OpenInAntigravityPlugin.AgentOpenInAntigravityPlugin.shared)
        plugins.append(OpenInCursorPlugin.AgentOpenInCursorPlugin.shared)
        plugins.append(OpenInFinderPlugin.AgentOpenInFinderPlugin.shared)
        plugins.append(OpenInGitHubDesktopPlugin.AgentOpenInGitHubDesktopPlugin.shared)
        plugins.append(OpenInGitOKPlugin.AgentOpenInGitOKPlugin.shared)
        plugins.append(OpenInXcodePlugin.AgentOpenInXcodePlugin.shared)
        plugins.append(OpenRemotePlugin.AgentOpenRemotePlugin.shared)
        plugins.append(PortManagerPlugin.PortManagerPlugin.shared)
        plugins.append(ProjectIssueScannerPlugin.ProjectIssueScannerPlugin.shared)
        plugins.append(ProjectOverviewPlugin.ProjectOverviewPlugin.shared)
        plugins.append(ProjectsPlugin.ProjectsPlugin.shared)
        plugins.append(QuickFileSearchPlugin.QuickFileSearchPlugin.shared)
        plugins.append(QuickLauncherPlugin.QuickLauncherPlugin.shared)
        plugins.append(RClickPlugin.RClickPlugin.shared)
        plugins.append(RegistryManagerPlugin.RegistryManagerPlugin.shared)
        plugins.append(RequestLogPlugin.RequestLogPlugin.shared)
        plugins.append(SampleDecorationEditorPlugin.SampleDecorationEditorPlugin.shared)
        plugins.append(SampleInsightsEditorPlugin.SampleInsightsEditorPlugin.shared)
        plugins.append(ScreenshotPlugin.ScreenshotPlugin.shared)
        plugins.append(ShowImagePlugin.ShowImagePlugin.shared)
        plugins.append(SkillPlugin.SkillPlugin.shared)
        plugins.append(SwiftPrimitiveTypesEditorPlugin.SwiftPrimitiveTypesEditorPlugin.shared)
        plugins.append(SwiftSelectionCodeActionEditorPlugin.SwiftSelectionCodeActionEditorPlugin.shared)
        plugins.append(TerminalPlugin.TerminalPlugin.shared)
        plugins.append(TextActionsPlugin.TextActionsPlugin.shared)
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
        plugins.append(ToolCallLoopDetectionPlugin.ToolCallLoopDetectionPlugin.shared)
        plugins.append(ToolPermissionPlugin.AgentToolPermissionPlugin.shared)
        plugins.append(VerbosityPlugin.VerbosityPlugin.shared)
        plugins.append(VueEditorPlugin.VueEditorPlugin.shared)
        plugins.append(WebFetchPlugin.WebFetchPlugin.shared)
        plugins.append(WebSearchPlugin.WebSearchPlugin.shared)
        plugins.append(WindowPersistencePlugin.WindowPersistencePlugin.shared)
        return plugins
    }
}
