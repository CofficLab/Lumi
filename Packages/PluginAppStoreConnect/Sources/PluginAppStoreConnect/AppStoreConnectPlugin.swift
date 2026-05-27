import Foundation
import LumiCoreKit
import SuperLogKit
import SwiftUI
import os

public actor AppStoreConnectPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-store-connect")

    public nonisolated static let emoji = ""
    public nonisolated static let verbose: Bool = true

    public static let id = "AppStoreConnect"
    public static let navigationId = "app_store_connect"
    public static let displayName = AppStoreConnectLocalization.string("App Store")
    public static let description = AppStoreConnectLocalization.string("Manage App Store Connect apps, metadata, and screenshots")
    public static let iconName = "bag"
    public static let isConfigurable: Bool = true
    public static var category: PluginCategory { .developerTool }
    public static var order: Int { 65 }
    
    /// 插件注册策略：可配置，默认不启用（用户可在设置中手动开启）
    public nonisolated static let shouldRegister: Bool = true
    public nonisolated static let enabledByDefault: Bool = false

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = AppStoreConnectPlugin()

    @MainActor
    public func addViewContainer() -> ViewContainerItem? {
        ViewContainerItem(id: Self.id, title: Self.displayName, icon: Self.iconName) {
            AnyView(AppStoreConnectView())
        }
    }

    @MainActor
    public func addToolBarCenterView(context: PluginContext) -> AnyView? {
        guard context.activeIcon == Self.iconName else { return nil }
        return AnyView(AppStoreConnectToolbarAppPicker())
    }
}

enum AppStoreConnectLocalization {
    static let table = "AppStoreConnect"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: table, bundle: bundle, value: key, comment: "")
    }

    static func string(_ key: String, _ args: CVarArg...) -> String {
        String(format: string(key), arguments: args)
    }
}
