import SwiftUI
import os

actor NetworkManagerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.network-manager")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "🛜"
    nonisolated static let verbose: Bool = true

    static let id = "NetworkManager"
    static let navigationId = "network_manager"
    static let displayName = String(localized: "Network Monitor", table: "NetworkManager")
    static let description = String(localized: "Real-time monitoring of network speed, traffic, and connection status", table: "NetworkManager")
    static let iconName = "network"
    static var category: PluginCategory { .system }
    static var order: Int { 30 }
    nonisolated static let policy: PluginPolicy = .optIn

    nonisolated var instanceLabel: String { Self.id }

    static let shared = NetworkManagerPlugin()

    // 不在 init 中创建 Task，避免时序与竞态。NetworkHistoryService.shared 在首次被
    // 访问时（如状态栏/仪表盘）会自行初始化。

    nonisolated func onEnable() {
        Task { @MainActor in
            NetworkManagerViewModel.shared.startMonitoring()
            NetworkHistoryService.shared.startRecording()
        }
    }

    nonisolated func onDisable() {
        Task { @MainActor in
            NetworkHistoryService.shared.stopRecording()
            NetworkManagerViewModel.shared.stopMonitoring()
        }
    }

    // MARK: - UI Contributions

    @MainActor
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "网络实时监控",
                subtitle: "在菜单栏和仪表盘查看网速、流量和连接状态。",
                icon: Self.iconName,
                accent: .cyan,
                metrics: [
                    PluginPosterSupport.metric("Up", "上传"),
                    PluginPosterSupport.metric("Down", "下载"),
                ],
                rows: ["实时网速", "流量历史", "连接状态"],
                chips: ["系统", "网络", "菜单栏"]
            ),
        ]
    }

    @MainActor func addMenuBarPopupView() -> AnyView? {
        AnyView(NetworkMenuBarPopupView())
    }

    @MainActor func addMenuBarContentView() -> AnyView? {
        AnyView(NetworkMenuBarContentView())
    }

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(NetworkDashboardView())
        }
    }
}

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
