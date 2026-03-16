import MagicKit
import SwiftUI

actor BrewManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties
    
    nonisolated static let emoji = "🍺"
    nonisolated static let enable: Bool = false
    nonisolated static let verbose: Bool = true
    
    static let id = "BrewManager"
    static let navigationId = "brew_manager"
    static let displayName = String(localized: "Package Management", table: "BrewManager")
    static let description = String(localized: "Manage Homebrew packages and casks", table: "BrewManager")
    static let iconName = "shippingbox"
    static var order: Int { 60 }
    nonisolated var instanceLabel: String { Self.id }
    static let shared = BrewManagerPlugin()
    
    // MARK: - UI Contributions
    
    @MainActor func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: Self.navigationId,
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                BrewManagerView()
            }
        ]
    }
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(BrewManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
