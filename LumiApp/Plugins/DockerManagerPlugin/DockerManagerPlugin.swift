import MagicKit
import SwiftUI

actor DockerManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🐳"
    static let enable = true
    nonisolated static let verbose = true

    static let id = "DockerManager"
    static let navigationId = "docker_manager"
    static let displayName = String(localized: "Docker", table: "DockerManager")
    static let description = String(localized: "Local Docker image management and monitoring", table: "DockerManager")
    static let iconName = "shippingbox"
    static var order: Int { 50 }

    nonisolated var instanceLabel: String { Self.id }

    static let shared = DockerManagerPlugin()

    init() {}

    // MARK: - UI Contributions

    @MainActor func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: Self.navigationId,
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                DockerImagesView()
            },
        ]
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation(DockerManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
