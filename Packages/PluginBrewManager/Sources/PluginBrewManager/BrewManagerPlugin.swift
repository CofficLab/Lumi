import Foundation
import LumiCoreKit
import SuperLogKit
import SwiftUI
import os

public actor BrewManagerPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.brew-manager")

    public nonisolated static let emoji = "🍺"
    public nonisolated static let enable: Bool = false
    public nonisolated static let verbose: Bool = true

    public static let id = "BrewManager"
    public static let navigationId = "brew_manager"
    public static let displayName = PluginBrewManagerLocalization.string("Package Management")
    public static let description = PluginBrewManagerLocalization.string("Manage Homebrew packages and casks")
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
    static let table = "BrewManager"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: table, bundle: bundle, value: key, comment: "")
    }
}
