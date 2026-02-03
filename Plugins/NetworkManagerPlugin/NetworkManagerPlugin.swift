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

    init() {
        // 确保在初始化时同步创建 HistoryService
        _ = NetworkHistoryService.shared
    }

    // MARK: - Lifecycle Hooks

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
