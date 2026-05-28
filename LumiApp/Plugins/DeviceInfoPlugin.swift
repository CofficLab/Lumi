import AgentToolKit
import PluginDeviceInfo
import SwiftUI
import os

actor DeviceInfoPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.device-info")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "💻"
    static var category: PluginCategory { .general }
    nonisolated static let verbose: Bool = PluginDeviceInfo.DeviceInfoPlugin.verbose

    static let id: String = PluginDeviceInfo.DeviceInfoPlugin.id
    static let navigationId: String = PluginDeviceInfo.DeviceInfoPlugin.navigationId
    static let displayName: String = PluginDeviceInfo.DeviceInfoPlugin.displayName
    static let description: String = PluginDeviceInfo.DeviceInfoPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginDeviceInfo.DeviceInfoPlugin.description(for: language)
    }
    static let iconName = PluginDeviceInfo.DeviceInfoPlugin.iconName
    static var order: Int { PluginDeviceInfo.DeviceInfoPlugin.order }
    nonisolated static let policy: PluginPolicy = .optIn

    // MARK: - Instance

    nonisolated var instanceLabel: String { Self.id }
    static let shared = DeviceInfoPlugin()

    @MainActor
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "设备状态监控",
                subtitle: "在菜单栏和详情页查看 CPU、内存与进程状态。",
                icon: Self.iconName,
                accent: .green,
                metrics: [
                    PluginPosterSupport.metric("CPU", "历史曲线"),
                    PluginPosterSupport.metric("RAM", "内存占用"),
                ],
                rows: ["顶部进程", "CPU 走势", "内存走势"],
                chips: ["菜单栏", "监控", "系统"]
            ),
        ]
    }

    nonisolated func onEnable() {
        PluginDeviceInfo.DeviceInfoPlugin.shared.onEnable()
    }

    nonisolated func onDisable() {
        PluginDeviceInfo.DeviceInfoPlugin.shared.onDisable()
    }

    // MARK: - UI Contributions

    @MainActor
    func addMenuBarContentView() -> AnyView? {
        PluginDeviceInfo.DeviceInfoPlugin.shared.addMenuBarContentView()
    }

    @MainActor
    func addMenuBarPopupViews() -> [AnyView] {
        PluginDeviceInfo.DeviceInfoPlugin.shared.addMenuBarPopupViews()
    }

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        guard let item = PluginDeviceInfo.DeviceInfoPlugin.shared.addViewContainer() else {
            return nil
        }
        return ViewContainerItem(id: item.id, title: item.title, icon: item.icon, makeView: item.makeView)
    }
}
