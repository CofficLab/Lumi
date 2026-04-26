import MagicKit
import SwiftUI
import os

actor DockerManagerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.docker-manager")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "🐳"
    nonisolated static let enable: Bool = false
    nonisolated static let verbose: Bool = true

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

    @MainActor func addPanelView() -> AnyView? {
        AnyView(DockerImagesView())
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
