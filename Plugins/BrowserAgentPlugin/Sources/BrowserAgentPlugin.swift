import AgentToolKit
import Foundation
import LumiCoreKit
import SuperLogKit
import os

/// Browser Agent 插件。
///
/// 提供浏览器自动化功能，基于 agent-browser CLI 工具。
/// 支持网页导航、元素交互、截图、快照等浏览器操作。
public actor BrowserAgentPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.browser-agent")

    public nonisolated static let emoji = "🌐"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let policy: PluginPolicy = .alwaysOn

    public static let id: String = "BrowserAgent"
    public static let displayName: String = PluginBrowserAgentLocalization.string("Browser Agent")
    public static let description: String = PluginBrowserAgentLocalization.string("Browser automation powered by agent-browser CLI")

    public static func description(for language: LanguagePreference) -> String {
        PluginBrowserAgentLocalization.string("Browser automation powered by agent-browser CLI", for: language)
    }
    public static let iconName: String = "globe"
    public static var category: PluginCategory { .general }
    public static var order: Int { 103 }

    public static let shared = BrowserAgentPlugin()

    private init() {}

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [BrowserAgentTool()]
    }
}

enum PluginBrowserAgentLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module, comment: "")
    }

    static func string(_ key: String, for language: LanguagePreference) -> String {
        PackageStringLocalization.string(key, table: table, bundle: bundle, language: language)
    }
}
