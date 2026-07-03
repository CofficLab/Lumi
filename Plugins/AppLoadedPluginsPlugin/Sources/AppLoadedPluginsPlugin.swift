import LumiCoreKit
import LumiUI
import SwiftUI
import os

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

public enum AppLoadedPluginsPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .general
    public static let iconName = "puzzlepiece.extension"
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.app-loaded-plugins")

    nonisolated(unsafe) public static var pluginProvider: @MainActor () -> [LoadedPluginInfo] = { [] }

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.app-loaded-plugins",
        displayName: PluginAppLoadedPluginsLocalization.string("App Plugins"),
        description: PluginAppLoadedPluginsLocalization.string("Show loaded app plugins in status bar"),
        order: 79
    )

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        [
            LumiStatusBarItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName,
                placement: .trailing,
                statusBarView: {
                    AppLoadedPluginsStatusBarView(pluginProvider: pluginProvider)
                }
            )
        ]
    }

        @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 16) {
                Text(info.displayName)
                    .font(.title2.weight(.semibold))
                Text(info.description)
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }

}

enum PluginAppLoadedPluginsLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: Bundle.module, table: "Localizable")
    }
}
