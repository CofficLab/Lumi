import SwiftUI
import MagicKit

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
    
    init() {}
    
    // MARK: - UI Contributions
    
    @MainActor func addStatusBarLeadingView() -> AnyView? {
        return AnyView(NetworkStatusTile())
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
            }
        ]
    }
}
