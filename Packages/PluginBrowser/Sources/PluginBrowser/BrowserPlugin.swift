import AgentToolKit
import Foundation
import LumiCoreKit
import SuperLogKit
import os

/// Browser 插件。
///
/// 提供网页截图功能。
/// 使用 WKWebView 渲染网页并截图，截图保存到系统临时目录返回文件路径。
public actor BrowserPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.browser")

    public nonisolated static let emoji = "🖼️"
    public nonisolated static let verbose: Bool = true

    public static let id: String = "Browser"
    public static let displayName: String = PluginBrowserLocalization.string("Browser")
    public static let description: String = PluginBrowserLocalization.string("提供网页渲染截图功能，使用 WKWebView 渲染网页并返回截图文件路径。")

    public static func description(for language: LanguagePreference) -> String {
        PluginBrowserLocalization.string("提供网页渲染截图功能，使用 WKWebView 渲染网页并返回截图文件路径。", for: language)
    }
    public static let iconName: String = "safari"
    public static var category: PluginCategory { .general }
    public static var order: Int { 102 }

    public static let shared = BrowserPlugin()

    private init() {}

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [BrowserScreenshotTool()]
    }
}

enum PluginBrowserLocalization {
    static let table = "Browser"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: table, bundle: bundle, value: key, comment: "")
    }

    static func string(_ key: String, for language: LanguagePreference) -> String {
        PackageStringLocalization.string(key, table: table, bundle: bundle, language: language)
    }
}
