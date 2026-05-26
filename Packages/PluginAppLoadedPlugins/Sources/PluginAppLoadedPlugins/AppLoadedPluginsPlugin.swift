import Foundation
import LumiCoreKit
import SuperLogKit
import SwiftUI

/// App 插件状态栏入口：在状态栏右侧显示已加载 App 插件数量与详情。
public actor AppLoadedPluginsPlugin: SuperPlugin, SuperLog {
    public nonisolated static let emoji = "🧩"
    public nonisolated static let enable: Bool = true
    public nonisolated static let verbose: Bool = true

    public static let id: String = "AppLoadedPlugins"
    public static let displayName: String = PluginAppLoadedPluginsLocalization.string("App Plugins")
    public static let description: String = PluginAppLoadedPluginsLocalization.string("Show loaded app plugins in status bar")
    public static let iconName: String = "puzzlepiece.extension"
    public static var isConfigurable: Bool { false }
    public static var category: PluginCategory { .general }
    public static var order: Int { 79 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = AppLoadedPluginsPlugin()

    nonisolated(unsafe) public static var pluginProvider: @MainActor () -> [LoadedPluginInfo] = { [] }

    private init() {}

    @MainActor
    public func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        AnyView(AppLoadedPluginsStatusBarView(pluginProvider: Self.pluginProvider))
    }
}

enum PluginAppLoadedPluginsLocalization {
    static let table = "AppLoadedPlugins"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: table, bundle: bundle, value: key, comment: "")
    }
}

public struct LoadedPluginInfo: Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String
    public let order: Int

    public init(id: String, displayName: String, description: String, order: Int) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.order = order
    }
}
