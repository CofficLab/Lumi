import SwiftUI
import Foundation

actor RegistryManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🔁"
    nonisolated static let verbose: Bool = true

    static let id = "RegistryManager"
    static let navigationId: String = "registry_manager"
    static let displayName = String(localized: "Registry Manager", table: "RegistryManager")
    static let description = String(localized: "Manage Lumi registries", table: "RegistryManager")
    static let iconName = "arrow.triangle.2.circlepath"
    static var category: PluginCategory { .system }
    static var order: Int { 80 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = RegistryManagerPlugin()

    // MARK: - UI

    @MainActor
    func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(RegistryManagerView())
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
