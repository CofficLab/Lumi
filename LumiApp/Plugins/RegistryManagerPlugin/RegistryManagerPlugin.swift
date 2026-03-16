import MagicKit
import SwiftUI
import Foundation

actor RegistryManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🔁"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id = "RegistryManager"
    static let navigationId: String = "registry_manager"
    static let displayName = String(localized: "Registry Manager", table: "RegistryManager")
    static let description = String(localized: "Manage Lumi registries", table: "RegistryManager")
    static let iconName = "arrow.triangle.2.circlepath"
    static let isConfigurable: Bool = false
    static var order: Int { 80 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = RegistryManagerPlugin()

    // MARK: - UI

    @MainActor
    func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: Self.navigationId,
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                AnyView(RegistryManagerView())
            }
        ]
    }
}
