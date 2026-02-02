import MagicKit
import SwiftUI

actor NetworkManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🛜"
    static let enable = true
    nonisolated static let verbose = true

    static let id = "NetworkManager"
    static let navigationId = "network_manager"
    static let displayName = "网络监控"
    static let description = "实时监控网络速度、流量和连接状态"
    static let iconName = "network"
    static var order: Int { 30 }

    nonisolated var instanceLabel: String { Self.id }

    static let shared = NetworkManagerPlugin()

    // MARK: - Lifecycle Hooks

    nonisolated func onRegister() {
        Task { @MainActor in
            NetworkStatusBarController.shared.start()
        }
    }

    nonisolated func onEnable() {
        Task { @MainActor in
            NetworkStatusBarController.shared.start()
        }
    }

    nonisolated func onDisable() {
        Task { @MainActor in
            NetworkStatusBarController.shared.stop()
        }
    }

    // MARK: - UI Contributions

    @MainActor func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: Self.navigationId,
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                NetworkDashboardView()
            },
        ]
    }
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .withNavigation(NetworkManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
