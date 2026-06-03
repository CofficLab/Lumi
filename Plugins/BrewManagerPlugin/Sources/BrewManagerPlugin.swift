import AgentToolKit
import Foundation
import LumiCoreKit
import SuperLogKit
import SwiftUI
import os

public actor BrewManagerPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.brew-manager")

    public nonisolated static let emoji = "🍺"
    public nonisolated static let policy: PluginPolicy = .optOut
    public nonisolated static let verbose: Bool = true

    public static let id = "BrewManager"
    public static let navigationId = "brew_manager"
    public static let displayName = PluginBrewManagerLocalization.string("Package Management")
    public static let description = PluginBrewManagerLocalization.string("Manage Homebrew packages and casks")

    public static func description(for language: LanguagePreference) -> String {
        PluginBrewManagerLocalization.string("Manage Homebrew packages and casks", for: language)
    }
    public static let iconName = "mug.fill"
    public static var category: PluginCategory { .developerTool }
    public static var order: Int { 60 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = BrewManagerPlugin()

    private init() {}

    @MainActor
    public func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(BrewManagerView())
        }
    }
}

enum PluginBrewManagerLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module, comment: "")
    }

    static func string(_ key: String, for language: LanguagePreference) -> String {
        PackageStringLocalization.string(key, table: table, bundle: bundle, language: language)
    }
}
