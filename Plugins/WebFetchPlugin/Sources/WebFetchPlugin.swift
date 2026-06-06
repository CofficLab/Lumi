import AgentToolKit
import Foundation
import LumiCoreKit
import SuperLogKit
import os

/// Web Fetch 插件。
///
/// 作为 package 化试点，插件适配层只负责把 `WebFetchTool` 注册到 Lumi 插件系统；
/// 实际网页抓取能力由 `WebFetchKit` 承载。
public actor WebFetchPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .disabled
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.web-fetch")

    public nonisolated static let emoji = "🌐"
    public nonisolated static let verbose: Bool = false

    public static let id: String = "WebFetch"
    public static let displayName: String = PluginWebFetchLocalization.string("Web Fetch")
    public static let description: String = PluginWebFetchLocalization.string("提供网页抓取和内容提取功能，支持 HTML 转 Markdown。")

    public static func description(for language: LanguagePreference) -> String {
        PluginWebFetchLocalization.string("提供网页抓取和内容提取功能，支持 HTML 转 Markdown。", for: language)
    }
    public static let iconName: String = "globe"
    public static var category: PluginCategory { .network }
    public static var order: Int { 100 }

    public static let shared = WebFetchPlugin()

    private init() {}

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [WebFetchTool()]
    }
}

enum PluginWebFetchLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module, comment: "")
    }

    static func string(_ key: String, for language: LanguagePreference) -> String {
        PackageStringLocalization.string(key, table: table, bundle: bundle, language: language)
    }
}
