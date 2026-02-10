import Foundation
import MagicKit
import SwiftUI
import OSLog

/// Navigation Plugin: Provides navigation buttons in the sidebar
actor NavigationPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    /// Log identifier
    nonisolated static let emoji = "🧭"

    /// Whether to enable this plugin
    static let enable = true

    /// Whether to enable verbose log output
    nonisolated static let verbose = true

    /// Plugin unique identifier
    static let id: String = "NavigationPlugin"

    /// Plugin display name
    static let displayName: String = "Navigation"

    /// Plugin functional description
    static let description: String = "Provides main navigation buttons in the sidebar"

    /// Plugin icon name
    static let iconName: String = "sidebar.left"

    /// Whether it is configurable
    static let isConfigurable: Bool = false
    
    /// Registration order
    static var order: Int { -1 }

    // MARK: - Instance

    /// Plugin instance label (used to identify unique instances)
    nonisolated var instanceLabel: String {
        Self.id
    }

    /// Plugin singleton instance
    static let shared = NavigationPlugin()

    /// Initialization method
    init() {}

    // MARK: - UI Contributions

    /// Add sidebar view
    /// - Returns: View to be added to the sidebar
    @MainActor func addSidebarView() -> AnyView? {
        return AnyView(NavigationSidebarView())
    }
}


