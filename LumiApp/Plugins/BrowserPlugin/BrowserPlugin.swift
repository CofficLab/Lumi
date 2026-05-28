import Foundation
import AgentToolKit
import PluginBrowser
import os

/// Browser 插件 App 侧注册适配器。
///
/// 当前 App 仍通过 ObjC runtime 扫描 `Lumi.*Plugin` 类注册插件；
/// package 中的 `PluginBrowser.BrowserPlugin` 不在 `Lumi` 命名空间内，
/// 因此这里保留一个薄适配器，实际实现转发给 package 插件。
actor BrowserPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.browser")

    /// 日志标识符
    nonisolated static let emoji = "🖼️"

    /// 是否启用详细日志
    nonisolated static let verbose: Bool = true

    static let id: String = PluginBrowser.BrowserPlugin.id
    static let displayName: String = PluginBrowser.BrowserPlugin.displayName
    static let description: String = PluginBrowser.BrowserPlugin.description

    static func description(for language: LanguagePreference) -> String {
        PluginBrowser.BrowserPlugin.description(for: language)
    }
    static let iconName: String = PluginBrowser.BrowserPlugin.iconName
    static var category: PluginCategory { .general }
    static var order: Int { PluginBrowser.BrowserPlugin.order }

    static let shared = BrowserPlugin()

    private init() {}

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [PluginBrowser.BrowserScreenshotTool()]
    }
}
