import AgentToolKit
import Foundation
import LumiCoreKit
import SuperLogKit
import SwiftUI
import os

public actor DiskManagerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.disk-manager")

    // MARK: - Plugin Properties

    public nonisolated static let emoji = "💿"
    public nonisolated static let verbose: Bool = false

    public static let id = "DiskManager"
    public static let navigationId = "disk_manager"
    public static let displayName = PluginDiskManagerLocalization.string("Disk Manager")
    public static let description = PluginDiskManagerLocalization.string("Disk space analysis and large file cleaning")

    public static func description(for language: LanguagePreference) -> String {
        PluginDiskManagerLocalization.string("Disk space analysis and large file cleaning", for: language)
    }
    public static let iconName = "internaldrive"
    public static var category: PluginCategory { .system }
    public static var order: Int { 22 }
    public nonisolated static let policy: PluginPolicy = .optOut

    public nonisolated var instanceLabel: String { Self.id }

    public static let shared = DiskManagerPlugin()

    private init() {}

    // MARK: - UI Contributions

    @MainActor
    public func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(DiskManagerView())
        }
    }
}

enum PluginDiskManagerLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module, comment: "")
    }

    static func string(_ key: String, for language: LanguagePreference) -> String {
        PackageStringLocalization.string(key, table: table, bundle: bundle, language: language)
    }
}
