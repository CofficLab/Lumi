import Foundation
import SuperLogKit
import os

/// Shared runtime state retained by the V2 App Manager plugin.
/// The old LumiPlugin entry point used to own these values; the migrated
/// lifecycle now lives in AppManagerSuperPlugin.
public enum AppManagerPlugin {
    nonisolated public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-manager")
    nonisolated public static let verbose = false
    nonisolated public static let railTabID = "app-manager.sidebar"
    nonisolated(unsafe) public static var pluginDataDirectoryProvider: () -> URL = {
        AppManagerPluginRuntimeBridge.fallbackPluginDataDirectory
    }
}

enum AppManagerPluginRuntimeBridge {
    static let fallbackPluginDataDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "4"
        let majorVersion = version.split(separator: ".").first.flatMap { Int($0) } ?? 4
        #if DEBUG
        let dbDirectoryName = "db_debug_v\(majorVersion)"
        #else
        let dbDirectoryName = "db_production_v\(majorVersion)"
        #endif
        return appSupport
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent(dbDirectoryName, isDirectory: true)
            .appendingPathComponent("AppManagerPlugin", isDirectory: true)
    }()
}
