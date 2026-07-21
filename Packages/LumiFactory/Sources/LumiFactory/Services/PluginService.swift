import Foundation
import LumiKernel
import AgentToolPlugin
import AppManagerPlugin
import BrewManagerPlugin
import ChatKernelPlugin
import ChatPanelPlugin
import ChatSectionPlugin
import ChatComposerPlugin
import ClipboardManagerPlugin
import CommandPlugin
import ConversationListPlugin
import ConversationStorePlugin
import ConversationTitlePlugin
import ConversationInputPlugin
import ConversationMessageCountPlugin
import MessageStorePlugin
import MessageSendManagerPlugin
import DeviceInfoPlugin
import DiskManagerPlugin
import DisplayControlPlugin
import DockerManagerPlugin
import EditorKernelPlugin
import EditorPanelPlugin
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
import MenuBarManagerPlugin
import MenuBarPlugin
import MessageListPlugin
import MessageRendererManagerPlugin
import MessageRendererPlugin
import NettoPlugin
import PanelPlugin
import PluginManagementPlugin
import PortManagerPlugin
import ProjectsPlugin
import QuickLauncherPlugin
import RClickPlugin
import RegistryManagerPlugin
import SendMiddlewarePlugin
import SettingsPlugin
import StatusBarPlugin
import StoragePlugin
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
import ThemeSummerPlugin
import ThemeVoidPlugin
import ThemeVscodePlugin
import ThemeWinterPlugin
import TitleToolbarPlugin
import VideoConverterPlugin
import ViewContainerPlugin
import WorkspaceStatePlugin

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
            PluginManagementPlugin(),
            LLMProviderManagerPlugin(),
            // LLM Providers (order 91-110)
            AiRouterPlugin(order: 91),
            DeepSeekPlugin(order: 92),
            StepFunPlugin(order: 93),
            FlyMuxPlugin(order: 94),
            FreeModelPlugin(order: 95),
            MLXLumiPlugin(order: 95),
            HappyCodePlugin(order: 96),
            HyperAPIPlugin(order: 97),
            LPgptPlugin(order: 98),
            MegaLLMPlugin(order: 99),
            OpenAIPlugin(order: 100),
            OpenRouterPlugin(order: 101),
            XiaomiPlugin(order: 102),
            KimiCodePlugin(order: 103),
            XybbzPlugin(order: 103),
            AnthropicPlugin(order: 104),
            FeifeimiaoPlugin(order: 104),
            MiniMaxPlugin(order: 104),
            SublyxPlugin(order: 104),
            AliyunPlugin(order: 105),
            CodexLumiPlugin(order: 105),
            ZhipuPlugin(order: 110),
            // UI & Features
            PanelPlugin(),
            TitleToolbarPlugin(),
            ProjectsPlugin(),
            AgentToolPlugin(),
            LayoutKernelPlugin(),
            EditorKernelPlugin(),
            EditorPanelPlugin(),
            ChatKernelPlugin(),
            ConversationStorePlugin(),
            MessageStorePlugin(),
            MessageSendManagerPlugin(),
            MessageRendererManagerPlugin(),
            MessageRendererPlugin(),
            ConversationTitlePlugin(),
            ConversationListPlugin(),
            CommandPlugin(),
            MenuBarPlugin(),
            SendMiddlewarePlugin(),
            ChatSectionPlugin(),
            ChatPanelPlugin(),
            ChatComposerPlugin(),
            MessageListPlugin(),
            ConversationInputPlugin(),
            ConversationMessageCountPlugin(),
            StatusBarPlugin(),
            SettingsPlugin(),
            LogoPlugin(),
            ViewContainerPlugin(),
            DeviceInfoPlugin(),
            ClipboardManagerPlugin(),
            BrewManagerPlugin(),
            DiskManagerPlugin(),
            HostsManagerPlugin(),
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
        ]

        // StoragePlugin (requires initialization)
        if let plugin = try? StoragePlugin() {
            list.append(plugin)
        }

        return list
    }()

}
