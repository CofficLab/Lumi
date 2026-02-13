import MagicKit
import SwiftUI

actor PortManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🔌"
    static let enable = true
    nonisolated static let verbose = true

    static let id = "PortManager"
    static let navigationId = "port_manager"
    static let displayName = String(localized: "Port Manager", table: "PortManager")
    static let description = String(localized: "View and manage port usage", table: "PortManager")
    static let iconName = "network"
    static var order: Int { 20 }

    nonisolated var instanceLabel: String { Self.id }

    static let shared = PortManagerPlugin()

    init() {}

    // MARK: - UI Contributions

    @MainActor func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: Self.navigationId,
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                PortManagerView()
            },
        ]
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(PortManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
