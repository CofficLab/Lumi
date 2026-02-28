import Foundation
import MagicKit
import SwiftUI

actor RegistryManagerPlugin: SuperPlugin {
    nonisolated static let id = "com.coffic.lumi.plugin.registrymanager"
    nonisolated static let displayName = String(localized: "Registry Manager", table: "RegistryManager")
    nonisolated static let navigationId = "\(id).main"

    @MainActor func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: Self.navigationId,
                title: Self.displayName,
                icon: "arrow.triangle.2.circlepath",
                pluginId: Self.id
            ) {
                AnyView(RegistryManagerView())
            }
        ]
    }
}
