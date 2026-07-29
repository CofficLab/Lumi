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
import BrewManagerPlugin
import BrowserPlugin
import CADDesignerPlugin
import CaffeinatePlugin
import ConversationAttachmentPlugin
import ChatFileAttachmentPlugin
import ChatModePlugin
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
import ConversationNewPlugin
import ConversationSpeedPlugin
import ConversationStorePlugin
import ConversationTitlePlugin
import DatabaseManagerPlugin
import DebugBadgePlugin
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
import IdleTimePlugin
import InputPlugin
import LayoutKernelPlugin
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
import MessageListPlugin
import MessageRendererPlugin
import MessageSenderPlugin
import MessageStorePlugin
import ModelSelectorPlugin
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
import PluginManagerPlugin
import PortManagerPlugin
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
import SharedUIPlugin
import ShowImagePlugin
import SkillPlugin
import StoragePlugin
import TerminalPlugin
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
import VerbosityPlugin
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
            SharedUIPlugin(),
            ToolManagerPlugin(),
            ProjectsPlugin(),
            LayoutKernelPlugin(),
            ConversationStorePlugin(),
            MessageStorePlugin(),
            MessageSenderPlugin(),
            AgentTurnRunnerPlugin(),
            MessageRendererPlugin(),
            ConversationTitlePlugin(),
            ConversationListPlugin(),
            ConversationNewPlugin(),
            ProjectRAGPlugin(),
            GitPlugin(),
            AgentRulesPlugin(),
            CommandPlugin(),
            ChatPanelPlugin(),
            ModelSelectorPlugin(),
            MessageListPlugin(),
            ConversationInputPlugin(),
            ConversationAttachmentPlugin(),
            ChatScreenshotPlugin(),
            ChatFileAttachmentPlugin(),
            PluginManagerPlugin(),
            ConversationMessageCountPlugin(),
            ConversationContextSizePlugin(),
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
            // Editor 预览面板 — 在 PanelBottom 显示文件预览。
            EditorPreviewBottomPanelPlugin(),
            TerminalPlugin(),
            DeviceInfoPlugin(),
            ProjectFileTreePlugin(),
            ClipboardManagerPlugin(),
            BrewManagerPlugin(),
            DiskManagerPlugin(),
            HostsManagerPlugin(),
            ConversationReasoningPlugin(),
            VerbosityPlugin(),
            ConversationSpeedPlugin(),
            ChatModePlugin(),
            ConversationLanguagePlugin(),
            VideoConverterPlugin(),
            NettoPlugin(),
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
            ActivityHeatmapPlugin(),
            FileLogPlugin(),
            OnboardingPlugin(),
            DatabaseManagerPlugin(),
            ConversationForkPlugin(),
            AgentTurnNotificationPlugin(),
            AppUpdatePlugin(),
            DebugBadgePlugin(),
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
            AgentOpenInAntigravityPlugin(),
            AgentOpenInGitHubDesktopPlugin(),
            AgentOpenInGitOKPlugin(),
            AgentOpenRemotePlugin(),
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
