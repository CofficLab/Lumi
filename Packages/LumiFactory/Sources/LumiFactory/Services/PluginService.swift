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
import ConversationManagerPlugin
import DeviceInfoPlugin
import DiskManagerPlugin
import DisplayControlPlugin
import DockerManagerPlugin
import EditorKernelPlugin
import EditorPanelPlugin
import HostsManagerPlugin
import InputPlugin
import LayoutKernelPlugin
import LogoPlugin
import MenuBarManagerPlugin
import MenuBarPlugin
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
import ThemeStatusBarPlugin
import ThemeSummerPlugin
import ThemeVoidPlugin
import ThemeVscodePlugin
import ThemeWinterPlugin
import TitleToolbarPlugin
import VideoConverterPlugin
import ViewContainerPlugin

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
            PluginManagementPlugin(),
            PanelPlugin(),
            TitleToolbarPlugin(),
            ProjectsPlugin(),
            AgentToolPlugin(),
            LayoutKernelPlugin(),
            EditorKernelPlugin(),
            EditorPanelPlugin(),
            ChatKernelPlugin(),
            ConversationManagerPlugin(),
            ConversationListPlugin(),
            CommandPlugin(),
            MenuBarPlugin(),
            SendMiddlewarePlugin(),
            ChatSectionPlugin(),
            ChatPanelPlugin(),
            ChatComposerPlugin(),
            // ChatPanel section plugins (legacy, now replaced by ChatComposerPlugin)
            ChatPendingSectionPlugin(),
            ChatAttachmentSectionPlugin(),
            ChatComposerSectionPlugin(),
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
