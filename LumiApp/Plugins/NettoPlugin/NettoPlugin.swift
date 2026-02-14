import SwiftUI

actor NettoPlugin: SuperPlugin {
    // MARK: - Plugin Properties
    
    static let id = "NettoPlugin"
    static let navigationId = "netto_plugin"
    static let displayName = String(localized: "Netto Firewall")
    static let description = String(localized: "Manage network permissions for macOS applications.")
    static let iconName = "shield.lefthalf.filled"
    static let order: Int = 99
    
    nonisolated var instanceLabel: String { Self.id }
    
    // MARK: - UI Contributions
    
    @MainActor func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: Self.navigationId,
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                NettoDashboardView()
            }
        ]
    }
}
