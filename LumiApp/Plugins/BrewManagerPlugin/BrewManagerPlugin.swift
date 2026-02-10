import MagicKit
import SwiftUI

actor BrewManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties
    
    nonisolated static let emoji = "🍺"
    static let enable = true
    nonisolated static let verbose = true
    
    static let id = "BrewManager"
    static let navigationId = "brew_manager"
    static let displayName = "软件包管理"
    static let description = "Manage Homebrew packages and casks"
    static let iconName = "shippingbox"
    static var order: Int { 60 }
    
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
        .hideTabPicker()
        .withNavigation(BrewManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
