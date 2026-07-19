import Foundation
import LumiKernel
import AgentToolPlugin
import AppManagerPlugin
import BrewManagerPlugin
import ChatKernelPlugin
import ChatSectionPlugin
import ClipboardManagerPlugin
import CommandPlugin
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
import ThemeLumiPlugin
import ThemeStatusBarPlugin
import TitleToolbarPlugin
import VideoConverterPlugin
import ViewContainerPlugin
import os

/// 插件服务
///
/// 维护静态插件列表，包含所有内置插件。
@MainActor
public enum PluginService {

    // MARK: - Plugin List

    /// 所有插件列表（静态）
    public static let plugins: [LumiPlugin] = {
        var list: [LumiPlugin] = []

        // PluginManagementPlugin
        list.append(PluginManagementPlugin())

        // StoragePlugin
        if let plugin = try? StoragePlugin() {
            list.append(plugin)
        }

        // ProjectsPlugin
        list.append(ProjectsPlugin())

        // AgentToolPlugin
        list.append(AgentToolPlugin())

        // LayoutKernelPlugin
        list.append(LayoutKernelPlugin())

        // EditorKernelPlugin
        list.append(EditorKernelPlugin())

        // EditorPanelPlugin
        list.append(EditorPanelPlugin())

        // ChatKernelPlugin
        list.append(ChatKernelPlugin())

        // CommandPlugin
        list.append(CommandPlugin())

        // MenuBarPlugin
        list.append(MenuBarPlugin())

        // TitleToolbarPlugin
        list.append(TitleToolbarPlugin())

        // SendMiddlewarePlugin
        list.append(SendMiddlewarePlugin())

        // ChatSectionPlugin
        list.append(ChatSectionPlugin())

        // PanelPlugin
        list.append(PanelPlugin())

        // StatusBarPlugin
        list.append(StatusBarPlugin())

        // SettingsPlugin
        list.append(SettingsPlugin())

        // LogoPlugin
        list.append(LogoPlugin())

        // ThemeStatusBarPlugin (合并了原 ThemePlugin 功能)
        list.append(ThemeStatusBarPlugin())

        // ThemeLumiPlugin
        list.append(ThemeLumiPlugin())

        // ViewContainerPlugin
        list.append(ViewContainerPlugin())

        // DeviceInfoPlugin
        list.append(DeviceInfoPlugin())

        // ClipboardManagerPlugin
        list.append(ClipboardManagerPlugin())

        // BrewManagerPlugin
        list.append(BrewManagerPlugin())

        // DiskManagerPlugin
        list.append(DiskManagerPlugin())

        // HostsManagerPlugin
        list.append(HostsManagerPlugin())

        // VideoConverterPlugin
        list.append(VideoConverterPlugin())

        // NettoPlugin
        list.append(NettoPlugin())

        // QuickLauncherPlugin
        list.append(QuickLauncherPlugin())

        // PortManagerPlugin
        list.append(PortManagerPlugin())

        // AppManagerPlugin
        list.append(AppManagerPlugin())

        // RegistryManagerPlugin
        list.append(RegistryManagerPlugin())

        // DisplayControlPlugin
        list.append(DisplayControlPlugin())

        // DockerManagerPlugin
        list.append(DockerManagerPlugin())

        // RClickPlugin
        list.append(RClickPlugin())

        // InputPlugin
        list.append(InputPlugin())

        // MenuBarManagerPlugin
        list.append(MenuBarManagerPlugin())

        return list
    }()
}
