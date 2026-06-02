import LumiCoreKit
import PluginAgentAvailableTools
import PluginAgentContextSync
import PluginAgentCoreTools
import PluginAgentDelayMessage
import PluginAgentGitHubTools
import PluginAgentLanguage
import PluginAgentMCPTools
import PluginAgentMessageRenderer
import PluginAgentRAG
import PluginAgentRules
import PluginAgentTurnNotification
import PluginAppIconDesigner
import PluginAppLoadedPlugins
import PluginAppManager
import PluginAppStoreConnect
import PluginAppUpdateStatusBar
import PluginAskUser
import PluginAutoTask
import PluginBrewManager
import PluginBrowser
import PluginBrowserAgent
import PluginCSSEditor
import PluginCaffeinate
import PluginChatAttachment
import PluginChatInput
import PluginChatMessages
import PluginChatMode
import PluginChatPanel
import PluginChatPendingMessages
import PluginChatSubmit
import PluginClipboardManager
import PluginCodeReview
import PluginConversationList
import PluginConversationNew
import PluginConversationTimeline
import PluginConversationTitle
import PluginDatabaseManager
import PluginDeviceInfo
import PluginDiskManager
import PluginDockerManager
import PluginEditorBottomCallHierarchy
import PluginEditorBottomProblems
import PluginEditorBottomReferences
import PluginEditorBottomSearch
import PluginEditorBottomSymbols
import PluginEditorBottomTerminal
import PluginEditorBreadcrumb
import PluginEditorCallHierarchyRail
import PluginEditorChatIntegration
import PluginEditorLSPContextCommands
import PluginEditorOutlineRail
import PluginEditorPanel
import PluginEditorPreview
import PluginEditorRailFileTree
import PluginEditorRailProblems
import PluginEditorRailReferences
import PluginEditorRailWorkspaceSearch
import PluginEditorRailWorkspaceSymbols
import PluginEditorStickySymbolBar
import PluginEditorSwiftKeywordHover
import PluginEditorTabStrip
import PluginEditorXcode
import PluginFileLog
import PluginFontConfig
import PluginGit
import PluginGitHubCLIDetect
import PluginGitHubInsight
import PluginGoEditor
import PluginHTMLEditor
import PluginHistoryDBStatusBar
import PluginHostsManager
import PluginIdleTime
import PluginInput
import PluginJSEditor
import PluginLLMAvailability
import PluginLLMProviderAiRouter
import PluginLLMProviderAliyun
import PluginLLMProviderAnthropic
import PluginLLMProviderCodex
import PluginLLMProviderDeepSeek
import PluginLLMProviderFeifeimiao
import PluginLLMProviderFlyMux
import PluginLLMProviderFreeModel
import PluginLLMProviderHappyCode
import PluginLLMProviderHyperAPI
import PluginLLMProviderLPgpt
import PluginLLMProviderMLX
import PluginLLMProviderMegaLLM
import PluginLLMProviderOpenAI
import PluginLLMProviderOpenRouter
import PluginLLMProviderXiaomi
import PluginLLMProviderXybbz
import PluginLLMProviderZhipu
import PluginLSPCallHierarchyEditor
import PluginLSPCodeActionEditor
import PluginLSPDocumentColorEditor
import PluginLSPDocumentHighlightEditor
import PluginLSPDocumentLinkEditor
import PluginLSPFoldingRangeEditor
import PluginLSPInlayHintEditor
import PluginLSPRealtimeSignalsEditor
import PluginLSPSelectionRangeEditor
import PluginLSPServiceEditor
import PluginLSPSheetsEditor
import PluginLSPSignatureHelpEditor
import PluginLSPToolbarEditor
import PluginLSPWorkspaceSymbolEditor
import PluginLayout
import PluginMarkdownEditor
import PluginMemory
import PluginMenuBarManager
import PluginModelPreference
import PluginModelSelector
import PluginMultiAgent
import PluginMultiCursorCommandsEditor
import PluginNetto
import PluginNetworkManager
import PluginOnboarding
import PluginOpenInAntigravity
import PluginOpenInCursor
import PluginOpenInFinder
import PluginOpenInGitHubDesktop
import PluginOpenInGitOK
import PluginOpenInXcode
import PluginOpenRemote
import PluginPortManager
import PluginProjectIssueScanner
import PluginProjectOverview
import PluginProjects
import PluginQuickFileSearch
import PluginQuickLauncher
import PluginRClick
import PluginRegistryManager
import PluginRequestLog
import PluginSampleDecorationEditor
import PluginSampleInsightsEditor
import PluginScreenshot
import PluginShowImage
import PluginSkill
import PluginSwiftPrimitiveTypesEditor
import PluginSwiftSelectionCodeActionEditor
import PluginTerminal
import PluginTextActions
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
import PluginToolCallLoopDetection
import PluginToolPermission
import PluginVerbosity
import PluginVueEditor
import PluginWebFetch
import PluginWebSearch
import PluginWindowPersistence

/// Central plugin registry.
///
/// Add packaged plugins here explicitly when they should be available to Lumi.
public enum GeneratedPluginRegistry {
    @MainActor
    public static var plugins: [any LumiCoreKit.SuperPlugin] {
        var plugins: [any LumiCoreKit.SuperPlugin] = []
        plugins.append(PluginAgentAvailableTools.AgentAvailableToolsPlugin.shared)
        plugins.append(PluginAgentContextSync.AgentContextSyncPlugin.shared)
        plugins.append(PluginAgentCoreTools.AgentCoreToolsPlugin.shared)
        plugins.append(PluginAgentDelayMessage.DelayMessagePlugin.shared)
        plugins.append(PluginAgentGitHubTools.GitHubToolsPlugin.shared)
        plugins.append(PluginAgentLanguage.AgentLanguagePlugin.shared)
        plugins.append(PluginAgentMCPTools.AgentMCPToolsPlugin.shared)
        plugins.append(PluginAgentMessageRenderer.MessageRendererPlugin.shared)
        plugins.append(PluginAgentRAG.RAGPlugin.shared)
        plugins.append(PluginAgentRules.AgentRulesPlugin.shared)
        plugins.append(PluginAgentTurnNotification.AgentTurnNotificationPlugin.shared)
        plugins.append(PluginAppIconDesigner.AppIconDesignerPlugin.shared)
        plugins.append(PluginAppLoadedPlugins.AppLoadedPluginsPlugin.shared)
        plugins.append(PluginAppManager.AppManagerPlugin.shared)
        plugins.append(PluginAppStoreConnect.AppStoreConnectPlugin.shared)
        plugins.append(PluginAppUpdateStatusBar.AppUpdateStatusBarPlugin.shared)
        plugins.append(PluginAskUser.AskUserPlugin.shared)
        plugins.append(PluginAutoTask.AutoTaskPlugin.shared)
        plugins.append(PluginBrewManager.BrewManagerPlugin.shared)
        plugins.append(PluginBrowser.BrowserPlugin.shared)
        plugins.append(PluginBrowserAgent.BrowserAgentPlugin.shared)
        plugins.append(PluginCSSEditor.CSSEditorPlugin.shared)
        plugins.append(PluginCaffeinate.CaffeinatePlugin.shared)
        plugins.append(PluginChatAttachment.ChatAttachmentPlugin.shared)
        plugins.append(PluginChatInput.ChatInputPlugin.shared)
        plugins.append(PluginChatMessages.AgentChatPlugin.shared)
        plugins.append(PluginChatMode.ChatModePlugin.shared)
        plugins.append(PluginChatPanel.ChatPanelPlugin.shared)
        plugins.append(PluginChatPendingMessages.ChatPendingMessagesPlugin.shared)
        plugins.append(PluginChatSubmit.ChatSubmitPlugin.shared)
        plugins.append(PluginClipboardManager.ClipboardManagerPlugin.shared)
        plugins.append(PluginCodeReview.CodeReviewPlugin.shared)
        plugins.append(PluginConversationList.ConversationListPlugin.shared)
        plugins.append(PluginConversationNew.ConversationNewHeaderPlugin.shared)
        plugins.append(PluginConversationTimeline.ConversationTimelinePlugin.shared)
        plugins.append(PluginConversationTitle.ConversationTitlePlugin.shared)
        plugins.append(PluginDatabaseManager.DatabaseManagerPlugin.shared)
        plugins.append(PluginDeviceInfo.DeviceInfoPlugin.shared)
        plugins.append(PluginDiskManager.DiskManagerPlugin.shared)
        plugins.append(PluginDockerManager.DockerManagerPlugin.shared)
        plugins.append(PluginEditorBottomCallHierarchy.EditorBottomCallHierarchyPlugin.shared)
        plugins.append(PluginEditorBottomProblems.EditorBottomProblemsPlugin.shared)
        plugins.append(PluginEditorBottomReferences.EditorBottomReferencesPlugin.shared)
        plugins.append(PluginEditorBottomSearch.EditorBottomSearchPlugin.shared)
        plugins.append(PluginEditorBottomSymbols.EditorBottomSymbolsPlugin.shared)
        plugins.append(PluginEditorBottomTerminal.EditorBottomTerminalPlugin.shared)
        plugins.append(PluginEditorBreadcrumb.BreadcrumbNavPlugin.shared)
        plugins.append(PluginEditorCallHierarchyRail.EditorCallHierarchyRailPlugin.shared)
        plugins.append(PluginEditorChatIntegration.EditorChatIntegrationPlugin.shared)
        plugins.append(PluginEditorLSPContextCommands.EditorLSPContextCommandsPlugin.shared)
        plugins.append(PluginEditorOutlineRail.EditorOutlineRailPlugin.shared)
        plugins.append(PluginEditorPanel.EditorPlugin.shared)
        plugins.append(PluginEditorPreview.EditorPreviewPlugin.shared)
        plugins.append(PluginEditorRailFileTree.EditorRailFileTreePlugin.shared)
        plugins.append(PluginEditorRailProblems.EditorRailProblemsPlugin.shared)
        plugins.append(PluginEditorRailReferences.EditorRailReferencesPlugin.shared)
        plugins.append(PluginEditorRailWorkspaceSearch.EditorRailWorkspaceSearchPlugin.shared)
        plugins.append(PluginEditorRailWorkspaceSymbols.EditorRailWorkspaceSymbolsPlugin.shared)
        plugins.append(PluginEditorStickySymbolBar.EditorStickySymbolBarPlugin.shared)
        plugins.append(PluginEditorSwiftKeywordHover.EditorSwiftKeywordHoverPlugin.shared)
        plugins.append(PluginEditorTabStrip.EditorTabStripPlugin.shared)
        plugins.append(PluginEditorXcode.EditorXcodePlugin.shared)
        plugins.append(PluginFileLog.FileLogPlugin.shared)
        plugins.append(PluginFontConfig.FontConfigPlugin.shared)
        plugins.append(PluginGit.GitPlugin.shared)
        plugins.append(PluginGitHubCLIDetect.GitHubCLIDetectPlugin.shared)
        plugins.append(PluginGitHubInsight.GitHubInsightPlugin.shared)
        plugins.append(PluginGoEditor.GoEditorPlugin.shared)
        plugins.append(PluginHTMLEditor.HTMLEditorPlugin.shared)
        plugins.append(PluginHistoryDBStatusBar.HistoryDBStatusBarPlugin.shared)
        plugins.append(PluginHostsManager.HostsManagerPlugin.shared)
        plugins.append(PluginIdleTime.IdleTimePlugin.shared)
        plugins.append(PluginInput.InputPlugin.shared)
        plugins.append(PluginJSEditor.JSEditorPlugin.shared)
        plugins.append(PluginLLMAvailability.LLMAvailabilityPlugin.shared)
        plugins.append(PluginLLMProviderAiRouter.AiRouterPlugin.shared)
        plugins.append(PluginLLMProviderAliyun.AliyunPlugin.shared)
        plugins.append(PluginLLMProviderAnthropic.AnthropicPlugin.shared)
        plugins.append(PluginLLMProviderCodex.CodexPlugin.shared)
        plugins.append(PluginLLMProviderDeepSeek.DeepSeekPlugin.shared)
        plugins.append(PluginLLMProviderFeifeimiao.FeifeimiaoPlugin.shared)
        plugins.append(PluginLLMProviderFlyMux.FlyMuxPlugin.shared)
        plugins.append(PluginLLMProviderFreeModel.FreeModelPlugin.shared)
        plugins.append(PluginLLMProviderHappyCode.HappyCodePlugin.shared)
        plugins.append(PluginLLMProviderHyperAPI.HyperAPIPlugin.shared)
        plugins.append(PluginLLMProviderLPgpt.LPgptPlugin.shared)
        plugins.append(PluginLLMProviderMLX.MLXPlugin.shared)
        plugins.append(PluginLLMProviderMegaLLM.MegaLLMPlugin.shared)
        plugins.append(PluginLLMProviderOpenAI.OpenAIPlugin.shared)
        plugins.append(PluginLLMProviderOpenRouter.OpenRouterPlugin.shared)
        plugins.append(PluginLLMProviderXiaomi.XiaomiPlugin.shared)
        plugins.append(PluginLLMProviderXybbz.XybbzPlugin.shared)
        plugins.append(PluginLLMProviderZhipu.ZhipuPlugin.shared)
        plugins.append(PluginLSPCallHierarchyEditor.LSPCallHierarchyEditorPlugin.shared)
        plugins.append(PluginLSPCodeActionEditor.LSPCodeActionEditorPlugin.shared)
        plugins.append(PluginLSPDocumentColorEditor.LSPDocumentColorEditorPlugin.shared)
        plugins.append(PluginLSPDocumentHighlightEditor.LSPDocumentHighlightEditorPlugin.shared)
        plugins.append(PluginLSPDocumentLinkEditor.LSPDocumentLinkEditorPlugin.shared)
        plugins.append(PluginLSPFoldingRangeEditor.LSPFoldingRangeEditorPlugin.shared)
        plugins.append(PluginLSPInlayHintEditor.LSPInlayHintEditorPlugin.shared)
        plugins.append(PluginLSPRealtimeSignalsEditor.LSPRealtimeSignalsEditorPlugin.shared)
        plugins.append(PluginLSPSelectionRangeEditor.LSPSelectionRangeEditorPlugin.shared)
        plugins.append(PluginLSPServiceEditor.LSPServiceEditorPlugin.shared)
        plugins.append(PluginLSPSheetsEditor.LSPSheetsEditorPlugin.shared)
        plugins.append(PluginLSPSignatureHelpEditor.LSPSignatureHelpEditorPlugin.shared)
        plugins.append(PluginLSPToolbarEditor.LSPToolbarEditorPlugin.shared)
        plugins.append(PluginLSPWorkspaceSymbolEditor.LSPWorkspaceSymbolEditorPlugin.shared)
        plugins.append(PluginLayout.LayoutPlugin.shared)
        plugins.append(PluginMarkdownEditor.MarkdownEditorPlugin.shared)
        plugins.append(PluginMemory.MemoryPlugin.shared)
        plugins.append(PluginMenuBarManager.MenuBarManagerPlugin.shared)
        plugins.append(PluginModelPreference.ModelPreferencePlugin.shared)
        plugins.append(PluginModelSelector.ModelSelectorPlugin.shared)
        plugins.append(PluginMultiAgent.MultiAgentPlugin.shared)
        plugins.append(PluginMultiCursorCommandsEditor.MultiCursorCommandsEditorPlugin.shared)
        plugins.append(PluginNetto.NettoPlugin.shared)
        plugins.append(PluginNetworkManager.NetworkManagerPlugin.shared)
        plugins.append(PluginOnboarding.OnboardingPlugin.shared)
        plugins.append(PluginOpenInAntigravity.AgentOpenInAntigravityPlugin.shared)
        plugins.append(PluginOpenInCursor.AgentOpenInCursorPlugin.shared)
        plugins.append(PluginOpenInFinder.AgentOpenInFinderPlugin.shared)
        plugins.append(PluginOpenInGitHubDesktop.AgentOpenInGitHubDesktopPlugin.shared)
        plugins.append(PluginOpenInGitOK.AgentOpenInGitOKPlugin.shared)
        plugins.append(PluginOpenInXcode.AgentOpenInXcodePlugin.shared)
        plugins.append(PluginOpenRemote.AgentOpenRemotePlugin.shared)
        plugins.append(PluginPortManager.PortManagerPlugin.shared)
        plugins.append(PluginProjectIssueScanner.ProjectIssueScannerPlugin.shared)
        plugins.append(PluginProjectOverview.ProjectOverviewPlugin.shared)
        plugins.append(PluginProjects.ProjectsPlugin.shared)
        plugins.append(PluginQuickFileSearch.QuickFileSearchPlugin.shared)
        plugins.append(PluginQuickLauncher.QuickLauncherPlugin.shared)
        plugins.append(PluginRClick.RClickPlugin.shared)
        plugins.append(PluginRegistryManager.RegistryManagerPlugin.shared)
        plugins.append(PluginRequestLog.RequestLogPlugin.shared)
        plugins.append(PluginSampleDecorationEditor.SampleDecorationEditorPlugin.shared)
        plugins.append(PluginSampleInsightsEditor.SampleInsightsEditorPlugin.shared)
        plugins.append(PluginScreenshot.ScreenshotPlugin.shared)
        plugins.append(PluginShowImage.ShowImagePlugin.shared)
        plugins.append(PluginSkill.SkillPlugin.shared)
        plugins.append(PluginSwiftPrimitiveTypesEditor.SwiftPrimitiveTypesEditorPlugin.shared)
        plugins.append(PluginSwiftSelectionCodeActionEditor.SwiftSelectionCodeActionEditorPlugin.shared)
        plugins.append(PluginTerminal.TerminalPlugin.shared)
        plugins.append(PluginTextActions.TextActionsPlugin.shared)
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
        plugins.append(PluginToolCallLoopDetection.ToolCallLoopDetectionPlugin.shared)
        plugins.append(PluginToolPermission.AgentToolPermissionPlugin.shared)
        plugins.append(PluginVerbosity.VerbosityPlugin.shared)
        plugins.append(PluginVueEditor.VueEditorPlugin.shared)
        plugins.append(PluginWebFetch.WebFetchPlugin.shared)
        plugins.append(PluginWebSearch.WebSearchPlugin.shared)
        plugins.append(PluginWindowPersistence.WindowPersistencePlugin.shared)
        return plugins
    }
}
