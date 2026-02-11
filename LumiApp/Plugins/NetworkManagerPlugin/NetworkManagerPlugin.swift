import MagicKit
import SwiftUI

actor NetworkManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🛜"
    static let enable = true
    nonisolated static let verbose = true

    static let id = "NetworkManager"
    static let navigationId = "network_manager"
    static let displayName = String(localized: "Network Monitor")
    static let description = String(localized: "Real-time monitoring of network speed, traffic, and connection status")
    static let iconName = "network"
    static var order: Int { 30 }

    nonisolated var instanceLabel: String { Self.id }

    nonisolated static let shared = NetworkManagerPlugin()

    init() {
        // Ensure HistoryService is created synchronously on initialization
        Task { @MainActor in
            _ = NetworkHistoryService.shared
        }
    }

    // MARK: - UI Contributions

    @MainActor func addStatusBarPopupView() -> AnyView? {
        AnyView(NetworkStatusBarPopupView())
    }

    @MainActor func addStatusBarContentView() -> AnyView? {
        AnyView(NetworkStatusBarContentView())
    }

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
