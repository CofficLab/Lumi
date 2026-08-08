import ActivityHeatmapPlugin
import AgentRulesPlugin
import AgentTempStoragePlugin
import AppUpdatePlugin
import AgentTurnNotificationPlugin
import AgentTurnRunnerPlugin
import AppIconDesignerPlugin
import AppManagerPlugin
import AppStoreConnectPlugin
import AskUserPlugin
import BookletMakerPlugin
import BrewManagerPlugin
import BrowserPlugin
import CADDesignerPlugin
import StoryWriterPlugin
import StateMonitorPlugin
import CaffeinatePlugin
import ConversationAttachmentPlugin
import ConversationPendingMessagePlugin
import ChatFileAttachmentPlugin
import ConversationModePlugin
import ChatPanelPlugin
import ChatScreenshotPlugin
import ClipboardManagerPlugin
import CommandPlugin
import ConversationForkPlugin
import ConversationInputPlugin
import ConversationLanguagePlugin
import ConversationListPlugin
import ConversationMessageCountPlugin
import ConversationContextSizePlugin
import ConversationAgentTurnCountPlugin
import ConversationNewPlugin
import ConversationSpeedPlugin
import ConversationManagerPlugin
import ConversationTitlePlugin
import DatabaseManagerPlugin
import DeviceInfoPlugin
import DiskManagerPlugin
import DisplayControlPlugin
import DockerManagerPlugin
import DocxReadPlugin
import DownloadPlugin
import EditorKernelPlugin
import EditorPanelPlugin
import EditorPreviewPlugin
import EditorProviderPlugin
import EditorSwiftPlugin
import FileLogPlugin
import Foundation
import GitHubPlugin
import GitPlugin
import GoalTaskPlugin
import HostsManagerPlugin
import ImageToPDFPlugin
import IdleTimePlugin
import InputPlugin
import WorkspacePlugin
import LegacyDataPlugin
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
import LLMProviderKimiCodePlugin
import LLMProviderLPgptPlugin
import LLMProviderManagerPlugin
import LLMProviderMegaLLMPlugin
import LLMProviderMiniMaxPlugin
import LLMProviderMLXPlugin
import LLMProviderOpenAIPlugin
import LLMProviderOpenRouterPlugin
import LLMProviderStepFunPlugin
import LLMProviderSublyxPlugin
import LLMProviderXiaomiPlugin
import LLMProviderXybbzPlugin
import LLMProviderZhipuPlugin
import LogoCofficPlugin
import LogoPlugin
import LogoSmartLightPlugin
import LumiKernel
import MemoryPlugin
import MenuBarManagerPlugin
import MenuBarHelperPlugin
import MessageListPlugin
import MessageListAppKitPlugin
import MessageRendererPlugin
import MessageStreamingPlugin
import MessageManagerPlugin
import MessageSenderPlugin
import ModelSelectorPlugin
import NettoPlugin
import NetworkManagerPlugin
import OnboardingPlugin
import OpenInAntigravityPlugin
import OpenInCursorPlugin
import OpenInVSCodePlugin
import OpenInFinderPlugin
import OpenInGitHubDesktopPlugin
import OpenInGitOKPlugin
import OpenInXcodePlugin
import OpenRemotePlugin
import PluginManagerPlugin
import PortManagerPlugin
import ProjectFileBreadcrumbPlugin
import ProjectFilesPlugin
import ProjectFileTreePlugin
import ProjectOverviewPlugin
import ProjectRAGPlugin
import ProjectsPlugin
import QuickFileSearchPlugin
import QuickLauncherPlugin
import RClickPlugin
import ConversationReasoningPlugin
import RegistryManagerPlugin
import SettingsPlugin
import ShowImagePlugin
import SkillPlugin
import StoragePlugin
import TerminalPlugin
import TextActionsPlugin
import ThemeAuroraPlugin
import ThemeAutumnPlugin
import ThemeDraculaPlugin
import ThemeGithubPlugin
import ThemeLumiPlugin
import ThemeManagerPlugin
import ThemeMidnightPlugin
import ThemeMountainPlugin
import ThemeNebulaPlugin
import ThemeOneDarkPlugin
import ThemeOrchardPlugin
import ThemeRiverPlugin
import ThemeSkyPlugin
import ThemeSpringPlugin
import ThemeSummerPlugin
import ThemeVoidPlugin
import ThemeVscodePlugin
import ThemeWinterPlugin
import ToolManagerPlugin
import ConversationVerbosityPlugin
import VideoConverterPlugin
import WebFetchPlugin
import WebSearchPlugin

/// 插件服务
///
/// 维护静态插件列表，包含所有内置插件。
@MainActor
public enum PluginService {
    // MARK: - Plugin List

    /// 所有插件列表（静态）
    public static let plugins: [LumiPlugin] = {
        var list: [LumiPlugin] = [
            // Core (order matters! PanelPlugin must register early for rail tabs)
            LLMProviderManagerPlugin(),
            // EditorKernelPlugin 必须先于 EditorProviderPlugin:
            // 前者在 OnBoot 注册具象 EditorService,后者在 OnReady resolve 并转发文件操作。
            EditorKernelPlugin(),
            EditorProviderPlugin(),
            // App settings tabs (General/Appearance) — order 1, must lead the sidebar

            // LLM Providers (order 91-110)
            AiRouterPlugin(),
            DeepSeekPlugin(),
            StepFunPlugin(),
            FlyMuxPlugin(),
            FreeModelPlugin(),
            MLXLumiPlugin(),
            HappyCodePlugin(),
            HyperAPIPlugin(),
            LPgptPlugin(),
            MegaLLMPlugin(),
            OpenAIPlugin(),
            OpenRouterPlugin(),
            XiaomiPlugin(),
            KimiCodePlugin(),
            XybbzPlugin(),
            AnthropicPlugin(),
            FeifeimiaoPlugin(),
            MiniMaxPlugin(),
            SublyxPlugin(),
            AliyunPlugin(),
            CodexLumiPlugin(),
            ZhipuPlugin(),
            // UI & Features
            ToolManagerPlugin(),
            ProjectsPlugin(),
            WorkspacePlugin(),
            ConversationManagerPlugin(),
            MessageManagerPlugin(),
            MessageSenderPlugin(),
            MessageStreamingPlugin(),
            AgentTurnRunnerPlugin(),
            MessageRendererPlugin(),
            ConversationTitlePlugin(),
            StateMonitorPlugin(),
            ConversationListPlugin(),
            ConversationNewPlugin(),
            ProjectRAGPlugin(),
            GitPlugin(),
            AgentRulesPlugin(),
            CommandPlugin(),
            ChatPanelPlugin(),
            ModelSelectorPlugin(),
            MessageListPlugin(),
            // Parallel native AppKit message list. Ships as `.disabled`; the
            // PluginManager filters it out until parity and performance
            // gates pass, so the host app continues to render the SwiftUI
            // message list above.
            MessageListAppKitPlugin(),
            ConversationInputPlugin(),
            ConversationAttachmentPlugin(),
            ConversationPendingMessagePlugin(),
            ChatScreenshotPlugin(),
            ChatFileAttachmentPlugin(),
            PluginManagerPlugin(),
            ConversationMessageCountPlugin(),
            ConversationContextSizePlugin(),
            ConversationAgentTurnCountPlugin(),
            SettingsPlugin(),
            LogoPlugin(),
            LogoCofficPlugin(),
            LogoSmartLightPlugin(),
            // Editor UI Shell — 贡献 "Code Editor" 视图容器,托管 EditorService。
            // 依赖 EditorKernelPlugin 在 OnBoot 注册的具象 EditorService。
            EditorPanelPlugin(),
            EditorSwiftPlugin(),
            // Project files panel — 在 PanelHeader 显示项目已打开的文件。
            ProjectFilesPlugin(),
            // Panel Header 面包屑导航 — 显示当前文件路径，点击跳转。仅依赖 LumiKernel。
            ProjectFileBreadcrumbPlugin(),
            // Editor 预览面板 — 在 PanelBottom 显示文件预览。
            EditorPreviewBottomPanelPlugin(),
            TerminalPlugin(),
            TextActionsPlugin(),
            DeviceInfoPlugin(),
            ProjectFileTreePlugin(),
            ClipboardManagerPlugin(),
            BrewManagerPlugin(),
            DiskManagerPlugin(),
            HostsManagerPlugin(),
            ConversationReasoningPlugin(),
            ConversationVerbosityPlugin(),
            ConversationSpeedPlugin(),
            ConversationModePlugin(),
            ConversationLanguagePlugin(),
            VideoConverterPlugin(),
            NettoPlugin(),
            ImageToPDFPlugin(),
            BookletMakerPlugin(),
            QuickLauncherPlugin(),
            PortManagerPlugin(),
            AppManagerPlugin(),
            RegistryManagerPlugin(),
            DisplayControlPlugin(),
            DockerManagerPlugin(),
            RClickPlugin(),
            InputPlugin(),
            IdleTimePlugin(),
            MenuBarManagerPlugin(),
            MenuBarHelperPlugin(),
            CaffeinatePlugin(),
            AgentTempStoragePlugin(),
            AppIconDesignerPlugin(),
            WebFetchPlugin(),
            WebSearchPlugin(),
            MemoryPlugin(),
            DownloadPlugin(),
            BrowserPlugin(),
            ShowImagePlugin(),
            GitHubPlugin(),
            GoalTaskPlugin(),
            QuickFileSearchPlugin(),
            SkillPlugin(),
            DocxReadPlugin(),
            NetworkManagerPlugin(),
            ProjectOverviewPlugin(),
            AppStoreConnectPlugin(),
            CADDesignerPlugin(),
            StoryWriterPlugin(),
            ActivityHeatmapPlugin(),
            FileLogPlugin(),
            OnboardingPlugin(),
            DatabaseManagerPlugin(),
            ConversationForkPlugin(),
            AgentTurnNotificationPlugin(),
            AppUpdatePlugin(),
            // User interaction
            AskUserPlugin(),
            // Themes
            ThemeManagerPlugin(),
            ThemeLumiPlugin(),
            ThemeAuroraPlugin(),
            ThemeAutumnPlugin(),
            ThemeDraculaPlugin(),
            ThemeGithubPlugin(),
            ThemeMidnightPlugin(),
            ThemeMountainPlugin(),
            ThemeNebulaPlugin(),
            ThemeOneDarkPlugin(),
            ThemeOrchardPlugin(),
            ThemeRiverPlugin(),
            ThemeSkyPlugin(),
            ThemeSpringPlugin(),
            ThemeSummerPlugin(),
            ThemeVoidPlugin(),
            ThemeVscodePlugin(),
            ThemeWinterPlugin(),
            // Open in external apps
            AgentOpenInFinderPlugin(),
            AgentOpenInXcodePlugin(),
            AgentOpenInCursorPlugin(),
            AgentOpenInVSCodePlugin(),
            AgentOpenInAntigravityPlugin(),
            AgentOpenInGitHubDesktopPlugin(),
            AgentOpenInGitOKPlugin(),
            OpenRemotePlugin(),
        ]

        // StoragePlugin (requires initialization)
        if let plugin = try? StoragePlugin() {
            list.append(plugin)
        }

        // LegacyDataPlugin (v4 → v5 migration, read-only legacy data access)
        list.append(LegacyDataPlugin())

        return list
    }()
}
