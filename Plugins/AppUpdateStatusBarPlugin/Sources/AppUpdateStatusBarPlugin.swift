import AgentToolKit
import Foundation
import LumiCoreKit
import SuperLogKit
import SwiftUI
import os

public actor AppUpdateStatusBarPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .disabled
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-update-status-bar")

    public nonisolated static let emoji = "⬆️"
    public nonisolated static let verbose: Bool = true

    public static let id = "AppUpdateStatusBar"
    public static let navigationId = "app_update_status_bar"
    public static let displayName = PluginAppUpdateStatusBarLocalization.string("App Update Status")
    public static let description = PluginAppUpdateStatusBarLocalization.string("Shows a menu bar reminder when an app update is ready to install.")

    public static func description(for language: LanguagePreference) -> String {
        PluginAppUpdateStatusBarLocalization.string("Shows a menu bar reminder when an app update is ready to install.", for: language)
    }
    public static let iconName = "arrow.down.circle"
    public static var category: PluginCategory { .general }
    public static var order: Int { 8 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = AppUpdateStatusBarPlugin()

    private init() {}

    nonisolated public func onEnable() {
        Task { @MainActor in
            AppUpdateStatusBarStore.shared.start()
        }
    }

    nonisolated public func onDisable() {
        Task { @MainActor in
            AppUpdateStatusBarStore.shared.stop()
        }
    }

    @MainActor
    public func addMenuBarContentView() -> AnyView? {
        AnyView(AppUpdateStatusBarContentView(store: AppUpdateStatusBarStore.shared))
    }

    @MainActor
    public func addMenuBarPopupView() -> AnyView? {
        AnyView(AppUpdateStatusBarPopupView(store: AppUpdateStatusBarStore.shared))
    }
}

enum PluginAppUpdateStatusBarLocalization {
    static let table = "AppUpdateStatusBar"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: table, bundle: bundle, value: key, comment: "")
    }

    static func string(_ key: String, for language: LanguagePreference) -> String {
        PackageStringLocalization.string(key, table: table, bundle: bundle, language: language)
    }
}
