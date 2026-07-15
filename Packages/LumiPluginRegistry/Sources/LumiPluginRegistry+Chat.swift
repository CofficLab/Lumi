// MARK: - Chat Plugins Imports
import Foundation
import LumiCoreKit
import OnboardingPlugin
import QuickFileSearchPlugin
import QuickLauncherPlugin
import AppUpdateStatusBarPlugin
import DeviceInfoPlugin
import NetworkManagerPlugin
import HostsManagerPlugin
import MenuBarManagerPlugin
import ChatPanelPlugin
import MessageListPlugin
import ModelSelectorPlugin

// MARK: - Chat Plugins Extension

extension LumiPluginRegistry {
    /// Chat 插件数组，包含所有聊天面板相关的插件。
    ///
    /// 包含：Onboarding、快速搜索、快速启动、设备信息、网络管理、Hosts 管理、菜单栏、聊天面板、消息列表、模型选择器
    public static let chatPlugins: [any LumiPlugin.Type] = [
        // MARK: - Quick Access

        OnboardingPlugin.self,
        QuickFileSearchPlugin.self,
        QuickLauncherPlugin.self,

        // MARK: - Status & Device

        AppUpdateStatusBarPlugin.self,
        DeviceInfoPlugin.self,

        // MARK: - Managers

        NetworkManagerPlugin.self,
        HostsManagerPlugin.self,
        MenuBarManagerPlugin.self,

        // MARK: - Chat UI

        ChatPanelPlugin.self,
        MessageListPlugin.self,
        ChatAttachmentSectionPlugin.self,
        ChatPendingSectionPlugin.self,
        ChatComposerSectionPlugin.self,

        // MARK: - Model Selection

        ModelSelectorPlugin.self,
    ]
}
