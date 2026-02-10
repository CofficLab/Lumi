import Foundation
import MagicKit
import OSLog
import SwiftUI

/// Welcome Plugin: Provides a welcome screen as a detail view
actor WelcomePlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    /// Log identifier
    nonisolated static let emoji = "⭐️"

    /// Whether to enable this plugin
    static let enable = true

    /// Whether to enable verbose log output
    nonisolated static let verbose = true

    /// Plugin unique identifier
    static let id: String = "WelcomePlugin"

    static let navigationId = "\(id).welcome"

    /// Plugin display name
    static let displayName: String = "Welcome"

    /// Plugin functional description
    static let description: String = "Displays the app's welcome interface and user guide"

    /// Plugin icon name
    static let iconName: String = "star.circle.fill"

    /// Whether it is configurable
    static let isConfigurable: Bool = true

    /// Registration order
    static var order: Int { 0 }

    // MARK: - Instance

    /// Plugin singleton instance
    static let shared = WelcomePlugin()

    // MARK: - UI Contributions

    /// Provide navigation entries
    /// - Returns: Array of navigation entries
    @MainActor func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: Self.navigationId,
                title: "Welcome",
                icon: "star.circle.fill",
                pluginId: Self.id,
                isDefault: true
            ) {
                WelcomeView()
            },
        ]
    }

    /// Add detail view
    /// - Returns: Detail view
    @MainActor func addDetailView() -> AnyView? {
        return AnyView(WelcomeView())
    }
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .withDebugBar()
}
