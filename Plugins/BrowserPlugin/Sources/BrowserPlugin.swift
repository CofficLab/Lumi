import AgentToolKit
import Foundation
import LumiCoreKit
import SuperLogKit
import os

/// Browser 插件。
///
/// 提供网页截图与浏览器自动化功能。
/// - `browser_screenshot`：使用 WKWebView 渲染网页并截图
/// - `browser_agent`：基于 agent-browser CLI 的浏览器自动化
public actor BrowserPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.browser")

    public nonisolated static let emoji = "🖼️"
    public nonisolated static let verbose: Bool = false

    public static let id: String = "Browser"
    public static let displayName: String = PluginBrowserLocalization.string("Browser")
    public static let description: String = PluginBrowserLocalization.string("提供网页截图与浏览器自动化功能，包括 WKWebView 截图和 agent-browser CLI 自动化。")

    public static func description(for language: LanguagePreference) -> String {
        PluginBrowserLocalization.string("提供网页截图与浏览器自动化功能，包括 WKWebView 截图和 agent-browser CLI 自动化。", for: language)
    }
    public static let iconName: String = "safari"
    public static var category: PluginCategory { .general }
    public static var order: Int { 102 }

    public static let shared = BrowserPlugin()

    private init() {}

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [
            BrowserScreenshotTool(),
            BrowserAgentTool(),
        ]
    }
}

enum PluginBrowserLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module, comment: "")
    }

    static func string(_ key: String, for language: LanguagePreference) -> String {
        PackageStringLocalization.string(key, table: table, bundle: bundle, language: language)
    }
}
