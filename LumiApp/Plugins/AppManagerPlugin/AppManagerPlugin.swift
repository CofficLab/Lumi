import MagicKit
import SwiftUI
import Foundation

/// 应用管理插件
actor AppManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties
    
    nonisolated static let emoji = "📱"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    
    static let id = "AppManager"
    static let navigationId = "app_manager"
    static let displayName = String(localized: "App Manager", table: "AppManager")
    static let description = String(localized: "Manage installed applications", table: "AppManager")
    static let iconName = "apps.ipad"
    static var order: Int { 40 }
    
    nonisolated var instanceLabel: String { Self.id }
    static let shared = AppManagerPlugin()

    // MARK: - UI

    @MainActor
    func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: Self.navigationId,
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id,
                isDefault: false
            ) {
                AnyView(AppManagerView())
            }
        ]
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(AppManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
