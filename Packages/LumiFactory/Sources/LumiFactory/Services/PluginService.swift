import Foundation
import LumiKernel
import AgentToolPlugin
import AppManagerPlugin
import BrewManagerPlugin
import ChatKernelPlugin
import ClipboardManagerPlugin
import DeviceInfoPlugin
import DiskManagerPlugin
import DisplayControlPlugin
import DockerManagerPlugin
import EditorKernelPlugin
import HostsManagerPlugin
import InputPlugin
import LayoutKernelPlugin
import NettoPlugin
import PortManagerPlugin
import ProjectsPlugin
import QuickLauncherPlugin
import RClickPlugin
import RegistryManagerPlugin
import StoragePlugin
import VideoConverterPlugin
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

        // ChatKernelPlugin
        list.append(ChatKernelPlugin())

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

        return list
    }()
}
