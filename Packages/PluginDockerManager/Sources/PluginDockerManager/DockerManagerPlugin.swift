import Foundation
import LumiCoreKit
import SuperLogKit
import SwiftUI
import os

public actor DockerManagerPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.docker-manager")

    public nonisolated static let emoji = "🐳"
    public nonisolated static let enable: Bool = false
    public nonisolated static let verbose: Bool = true

    public static let id = "DockerManager"
    public static let navigationId = "docker_manager"
    public static let displayName = PluginDockerManagerLocalization.string("Docker")
    public static let description = PluginDockerManagerLocalization.string("Local Docker image management and monitoring")
    public static let iconName = "shippingbox"
    public static var category: PluginCategory { .developerTool }
    public static var order: Int { 50 }

    public nonisolated var instanceLabel: String { Self.id }

    public static let shared = DockerManagerPlugin()

    private init() {}

    @MainActor
    public func addPanelView(activeIcon: String?) -> AnyView? {
        guard activeIcon == Self.iconName else { return nil }
        return AnyView(DockerImagesView())
    }

    public nonisolated func addPanelIcon() -> String? { Self.iconName }
}

enum PluginDockerManagerLocalization {
    static let table = "DockerManager"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: table, bundle: bundle, value: key, comment: "")
    }
}
