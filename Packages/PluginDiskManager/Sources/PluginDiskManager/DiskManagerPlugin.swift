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
    public nonisolated static let enable: Bool = true
    public nonisolated static let verbose: Bool = true

    public static let id = "DiskManager"
    public static let navigationId = "disk_manager"
    public static let displayName = PluginDiskManagerLocalization.string("Disk Manager")
    public static let description = PluginDiskManagerLocalization.string("Disk space analysis and large file cleaning")
    public static let iconName = "internaldrive"
    public static var category: PluginCategory { .system }
    public static var order: Int { 22 }

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
    static let table = "DiskManager"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: table, bundle: bundle, value: key, comment: "")
    }
}
