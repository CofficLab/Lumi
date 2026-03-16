import MagicKit
import SwiftUI

actor RClickPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🖱️"
    nonisolated static let enable: Bool = false
    nonisolated static let verbose: Bool = false

    static let id = "RClick"
    static let navigationId: String? = "rclick"
    static let displayName = String(localized: "Right Click", table: "RClick")
    static let description = String(localized: "Customize Finder right-click menu actions", table: "RClick")
    static let iconName = "cursorarrow.click.2"
    static let isConfigurable: Bool = false
    static var order: Int { 50 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = RClickPlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {
        Task { @MainActor in
            _ = RClickConfigManager.shared
        }
    }

    // MARK: - UI

    @MainActor
    func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: Self.navigationId ?? Self.id,
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                RClickSettingsView()
            },
        ]
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(RClickPlugin.id)
        .inRootView()
        .withDebugBar()
}
