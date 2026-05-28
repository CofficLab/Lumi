import Foundation
import LumiCoreKit
import SuperLogKit
import SwiftUI
import os

/// 应用管理插件
public actor AppManagerPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-manager")

    // MARK: - Plugin Properties
    
    public nonisolated static let emoji = "📱"
    public nonisolated static let verbose: Bool = true
    public nonisolated(unsafe) static var databaseRootURLProvider: @Sendable () -> URL = {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.Lumi"
        return appSupportURL.appendingPathComponent(bundleID, isDirectory: true)
    }
    
    public static let id = "AppManager"
    public static let navigationId = "app_manager"
    public static let displayName = PluginAppManagerLocalization.string("App Manager")
    public static let description = PluginAppManagerLocalization.string("Manage installed applications")
    public static let iconName = "apps.ipad"
    public static var category: PluginCategory { .system }
    public static var order: Int { 40 }
    
    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = AppManagerPlugin()

    private init() {}

    // MARK: - UI

    @MainActor
    public func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(AppManagerView())
        }
    }
}

enum PluginAppManagerLocalization {
    static let table = "AppManager"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: table, bundle: bundle, value: key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: Locale.current, arguments: arguments)
    }
}
