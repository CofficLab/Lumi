import AgentToolKit
import Foundation
import LumiCoreKit
import SuperLogKit
import SwiftUI
import os

public actor DockerManagerPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.docker-manager")

    public nonisolated static let emoji = "🐳"
    public nonisolated static let policy: PluginPolicy = .disabled
    public nonisolated static let verbose: Bool = true

    public static let id = "DockerManager"
    public static let navigationId = "docker_manager"
    public static let displayName = PluginDockerManagerLocalization.string("Docker")
    public static let description = PluginDockerManagerLocalization.string("Local Docker image management and monitoring")

    public static func description(for language: LanguagePreference) -> String {
        PluginDockerManagerLocalization.string("Local Docker image management and monitoring", for: language)
    }
    public static let iconName = "shippingbox"
    public static var category: PluginCategory { .developerTool }
    public static var order: Int { 50 }

    public nonisolated var instanceLabel: String { Self.id }

    public static let shared = DockerManagerPlugin()

    private init() {}

    @MainActor
    public func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(DockerImagesView())
        }
    }
}

enum PluginDockerManagerLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module, comment: "")
    }

    static func string(_ key: String, for language: LanguagePreference) -> String {
        PackageStringLocalization.string(key, table: table, bundle: bundle, language: language)
    }
}
