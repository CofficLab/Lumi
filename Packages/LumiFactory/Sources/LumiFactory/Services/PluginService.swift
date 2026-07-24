import Foundation
import LumiKernel
import AgentTurnRunnerPlugin
import ToolManagerPlugin
import AppManagerPlugin
import BrewManagerPlugin
import ChatPanelPlugin
import ChatSectionPlugin
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
import EditorKernelPlugin
import EditorPanelPlugin
import EditorFileTreePlugin
import EditorFileTreeV2Plugin
import HostsManagerPlugin
import InputPlugin
import LayoutKernelPlugin
import LLMProviderManagerPlugin
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
import LogoPlugin
import LogoCofficPlugin
import LogoSmartLightPlugin
import MenuBarManagerPlugin
import MenuBarPlugin
import MessageListPlugin
import MessageRendererPlugin
import ModelSelectorPlugin
import NettoPlugin
import PanelPlugin
import PortManagerPlugin
import ProjectsPlugin
import QuickLauncherPlugin
import RClickPlugin
import RegistryManagerPlugin
import SettingsPlugin
import StatusBarPlugin
import StoragePlugin
import ThemeAuroraPlugin
import ThemeStatusBarPlugin
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
import TitleToolbarPlugin
import VerbosityPlugin
import ConversationSpeedPlugin
import ChatModePlugin
import VideoConverterPlugin
import ViewContainerPlugin
import WorkspaceStatePlugin
import OpenInFinderPlugin
import OpenInXcodePlugin
import OpenInCursorPlugin
import OpenInAntigravityPlugin
import OpenInGitHubDesktopPlugin
import OpenInGitOKPlugin
import OpenRemotePlugin

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
            WorkspaceStatePlugin(),
            LLMProviderManagerPlugin(),
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
            PanelPlugin(),
            TitleToolbarPlugin(),
            ToolManagerPlugin(),
            ProjectsPlugin(),
            LayoutKernelPlugin(),
            EditorKernelPlugin(),
            EditorPanelPlugin(),
            EditorFileTreePanelPlugin(),
            EditorFileTreeV2Plugin(),
            ConversationStorePlugin(),
            MessageStorePlugin(),
            MessageSenderPlugin(),
            AgentTurnRunnerPlugin(),
            MessageRendererPlugin(),
            ConversationTitlePlugin(),
            ConversationListPlugin(),
            ConversationNewPlugin(),
            CommandPlugin(),
            MenuBarPlugin(),
            ChatSectionPlugin(),
            ChatPanelPlugin(),
            ModelSelectorPlugin(),
            MessageListPlugin(),
            ConversationInputPlugin(),
            ChatAttachmentPreviewPlugin(),
            ChatScreenshotPlugin(),
            ChatFileAttachmentPlugin(),
            PluginManagerPlugin(),
            ConversationMessageCountPlugin(),
            StatusBarPlugin(),
            SettingsPlugin(),
            LogoPlugin(),
            LogoCofficPlugin(),
            LogoSmartLightPlugin(),
            ViewContainerPlugin(),
            DeviceInfoPlugin(),
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
            // Themes
            ThemeStatusBarPlugin(),
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

        return list
    }()

}
