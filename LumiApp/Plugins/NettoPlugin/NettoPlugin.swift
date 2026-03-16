import MagicKit
import SwiftUI

actor NettoPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🛡️"
    nonisolated static let enable: Bool = false
    nonisolated static let verbose: Bool = false

    static let id = "Netto"
    static let navigationId = "netto_firewall"
    static let displayName = String(localized: "Netto Firewall", table: "Netto")
    static let description = String(localized: "Manage network permissions for macOS applications.", table: "Netto")
    static let iconName = "shield.lefthalf.filled"
    static var order: Int { 99 }
    
    nonisolated var instanceLabel: String { Self.id }
    static let shared = NettoPlugin()
    
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
