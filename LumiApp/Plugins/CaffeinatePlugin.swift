import AgentToolKit
import LumiCoreKit
import PluginCaffeinate
import SwiftUI
import os

actor CaffeinatePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.caffeinate")

    nonisolated static let emoji = "☕️"
    nonisolated static let verbose: Bool = PluginCaffeinate.CaffeinatePlugin.verbose

    static let id = PluginCaffeinate.CaffeinatePlugin.id
    static let navigationId = PluginCaffeinate.CaffeinatePlugin.navigationId
    static let displayName = PluginCaffeinate.CaffeinatePlugin.displayName
    static let description = PluginCaffeinate.CaffeinatePlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginCaffeinate.CaffeinatePlugin.description(for: language)
    }
    static let iconName = PluginCaffeinate.CaffeinatePlugin.iconName
    static var category: PluginCategory { .system }
    static var order: Int { PluginCaffeinate.CaffeinatePlugin.order }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = CaffeinatePlugin()

    @MainActor
    func addMenuBarPopupView() -> AnyView? {
        PluginCaffeinate.CaffeinatePlugin.shared.addMenuBarPopupView()
    }

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        let packageContext = LumiCoreKit.ToolContext(languagePreference: context.languagePreference)
        return PluginCaffeinate.CaffeinatePlugin.shared.agentTools(context: packageContext)
    }
}
