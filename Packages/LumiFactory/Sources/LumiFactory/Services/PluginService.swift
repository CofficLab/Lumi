import Foundation
import LumiKernel
import AgentTurnRunnerPlugin
import ToolManagerPlugin
import AppManagerPlugin
import BrewManagerPlugin
import ChatPanelPlugin
import SharedUIPlugin
import ClipboardManagerPlugin
import CommandPlugin
import ConversationListPlugin
import ConversationNewPlugin
import ConversationStorePlugin
import ConversationTitlePlugin
import ConversationInputPlugin
import ConversationMessageCountPlugin
import ChatAttachmentPreviewPlugin
import ChatScreenshotPlugin
import ChatFileAttachmentPlugin
import PluginManagerPlugin
import HostSettingsPlugin
import MessageStorePlugin
import MessageSenderPlugin
import DeviceInfoPlugin
import DiskManagerPlugin
import DisplayControlPlugin
import DockerManagerPlugin
import EditorProviderPlugin
import EditorKernelPlugin
import EditorPanelPlugin
import ProjectFilesPlugin
import EditorPreviewPlugin
import TerminalPlugin
import HostsManagerPlugin
import InputPlugin
import LayoutKernelPlugin
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
import LLMProviderManagerPlugin
import LogoPlugin
import LogoCofficPlugin
import LogoSmartLightPlugin
import MenuBarManagerPlugin
import MessageListPlugin
import MessageRendererPlugin
import ModelSelectorPlugin
import NettoPlugin
import PortManagerPlugin
import ProjectsPlugin
import QuickLauncherPlugin
import RClickPlugin
import RegistryManagerPlugin
import SettingsPlugin
import StoragePlugin
import LegacyDataPlugin
import ThemeAuroraPlugin
import ThemeManagerPlugin
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
import ThemeSummerPlugin
import ThemeVoidPlugin
import ThemeVscodePlugin
import ThemeWinterPlugin
import VerbosityPlugin
import ConversationSpeedPlugin
import ChatModePlugin
import VideoConverterPlugin
import ProjectFileTreePlugin
import OpenInFinderPlugin
import OpenInXcodePlugin
import OpenInCursorPlugin
import OpenInAntigravityPlugin
import OpenInGitHubDesktopPlugin
import OpenInGitOKPlugin
import OpenRemotePlugin
import ProjectRAGPlugin
import GitPlugin
import AgentRulesPlugin
import CaffeinatePlugin
import AgentTempStoragePlugin
import AppIconDesignerPlugin
import WebFetchPlugin
import WebSearchPlugin
import MemoryPlugin
import DownloadPlugin
import BrowserPlugin
import ShowImagePlugin
import GitHubPlugin
import GoalTaskPlugin
// import CADDesignerPlugin  // Not included in Xcode project

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
            // Host settings tabs (General/Appearance/About) — order 1, must lead the sidebar
            HostSettingsPlugin(),
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
            ChatAttachmentPreviewPlugin(),
            ChatScreenshotPlugin(),
            ChatFileAttachmentPlugin(),
            PluginManagerPlugin(),
            ConversationMessageCountPlugin(),
            SettingsPlugin(),
            LogoPlugin(),
            LogoCofficPlugin(),
            LogoSmartLightPlugin(),
            // Editor UI Shell — 贡献 "Code Editor" 视图容器,托管 EditorService。
            // 依赖 EditorKernelPlugin 在 OnBoot 注册的具象 EditorService。
            EditorPanelPlugin(),
            // Project files panel — 在 PanelHeader 显示项目已打开的文件。
            ProjectFilesPlugin(),
            // Editor 预览面板 — 在 PanelBottom 显示文件预览。
            EditorPreviewBottomPanelPlugin(),
            TerminalPlugin(),
            // CADDesignerPlugin(),  // Not included in Xcode project
            DeviceInfoPlugin(),
            ProjectFileTreePlugin(),
            ClipboardManagerPlugin(),
            BrewManagerPlugin(),
            DiskManagerPlugin(),
            HostsManagerPlugin(),
            VerbosityPlugin(),
            ConversationSpeedPlugin(),
            ChatModePlugin(),
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
