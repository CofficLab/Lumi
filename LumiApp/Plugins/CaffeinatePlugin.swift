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
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "保持唤醒",
                subtitle: "从菜单栏或 Agent 工具控制系统防休眠和关闭显示器。",
                icon: Self.iconName,
                accent: .orange,
                metrics: [
                    PluginPosterSupport.metric("Awake", "防休眠"),
                    PluginPosterSupport.metric("Display", "显示器"),
                ],
                rows: ["菜单栏控制", "定时保持唤醒", "关闭显示器工具"],
                chips: ["系统", "菜单栏", "Agent 工具"]
            ),
        ]
    }

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
