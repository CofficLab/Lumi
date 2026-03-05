import MagicKit
import SwiftUI

actor HostsManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "📝"
    static let enable = true
    nonisolated static let verbose = true

    static let id = "HostsManager"
    static let navigationId = "hosts_manager"
    static let displayName = String(localized: "Hosts Manager", table: "HostsManager")
    static let description = String(localized: "Manage system hosts file configuration", table: "HostsManager")
    static let iconName = "list.bullet.rectangle"
    static var order: Int { 21 }

    nonisolated var instanceLabel: String { Self.id }

    static let shared = HostsManagerPlugin()

    // MARK: - UI Contributions

    @MainActor func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: Self.navigationId,
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                HostsManagerView()
            },
        ]
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(HostsManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
