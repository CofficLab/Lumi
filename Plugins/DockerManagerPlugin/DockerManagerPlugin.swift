import SwiftUI
import MagicKit

actor DockerManagerPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties
    
    nonisolated static let emoji = "🐳"
    static let enable = true
    nonisolated static let verbose = true
    
    static let id = "DockerManager"
    static let displayName = "Docker 管理"
    static let description = "本地 Docker 镜像管理与监控"
    static let iconName = "shippingbox"
    static var order: Int { 50 }
    
    nonisolated var instanceLabel: String { Self.id }
    
    static let shared = DockerManagerPlugin()
    
    init() {}
    
    // MARK: - UI Contributions
    
    @MainActor func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: "docker_manager",
                title: Self.displayName,
                icon: Self.iconName,
                pluginId: Self.id
            ) {
                DockerImagesView()
            }
        ]
    }
}
