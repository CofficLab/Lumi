import MagicKit
import SwiftUI
import os

actor NetworkManagerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.network-manager")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "🛜"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true

    static let id = "NetworkManager"
    static let navigationId = "network_manager"
    static let displayName = String(localized: "Network Monitor", table: "NetworkManager")
    static let description = String(localized: "Real-time monitoring of network speed, traffic, and connection status", table: "NetworkManager")
    static let iconName = "network"
    static var order: Int { 30 }

    nonisolated var instanceLabel: String { Self.id }

    static let shared = NetworkManagerPlugin()

    // 不在 init 中创建 Task，避免时序与竞态。NetworkHistoryService.shared 在首次被
    // 访问时（如状态栏/仪表盘）会自行初始化。

    // MARK: - UI Contributions

    

    @MainActor func addStatusBarPopupView() -> AnyView? {
        AnyView(NetworkStatusBarPopupView())
    }

    @MainActor func addStatusBarContentView() -> AnyView? {
        AnyView(NetworkStatusBarContentView())
    }

    @MainActor
    func addPanelView(activeIcon: String?) -> AnyView? {
        guard activeIcon == Self.iconName else { return nil }
        return AnyView(NetworkDashboardView())
    }

    nonisolated func addPanelIcon() -> String? { Self.iconName }
}

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
