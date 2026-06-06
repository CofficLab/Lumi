import AgentToolKit
import Foundation
import LumiCoreKit
import SuperLogKit
import SwiftUI
import os

public actor AppStoreConnectPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-store-connect")

    public nonisolated static let emoji = ""
    public nonisolated static let verbose: Bool = false

    public static let id = "AppStoreConnect"
    public static let navigationId = "app_store_connect"
    public static let displayName = AppStoreConnectLocalization.string("App Store")
    public static let description = AppStoreConnectLocalization.string("Manage App Store Connect apps, metadata, and screenshots")

    public static func description(for language: LanguagePreference) -> String {
        AppStoreConnectLocalization.string("Manage App Store Connect apps, metadata, and screenshots", for: language)
    }
    public static let iconName = "bag"
    public static var category: PluginCategory { .developerTool }
    public static var order: Int { 65 }
    
    /// 插件注册策略：可配置，默认不启用（用户可在设置中手动开启）
    public nonisolated static let policy: PluginPolicy = .disabled

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
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module, comment: "")
    }

    static func string(_ key: String, for language: LanguagePreference) -> String {
        PackageStringLocalization.string(key, table: table, bundle: bundle, language: language)
    }

    static func string(_ key: String, _ args: CVarArg...) -> String {
        String(format: string(key), arguments: args)
    }
}
