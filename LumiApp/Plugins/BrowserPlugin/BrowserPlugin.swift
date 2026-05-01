import Foundation
import MagicKit
import os

/// Browser 插件
///
/// 提供网页截图功能。
/// 使用 WKWebView 渲染网页并截图，截图保存到系统临时目录返回文件路径。
actor BrowserPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.browser")

    /// 日志标识符
    nonisolated static let emoji = "🖼️"

    /// 是否启用详细日志
    nonisolated static let verbose: Bool = false

    static let id: String = "Browser"
    static let displayName: String = "Browser"
    static let description: String = "提供网页渲染截图功能，使用 WKWebView 渲染网页并返回截图文件路径。"
    static let iconName: String = "safari"
    static let isConfigurable: Bool = false
    static let enable: Bool = true
    static var order: Int { 102 }

    static let shared = BrowserPlugin()

    private init() {}

    @MainActor
    func agentToolFactories() -> [AnySuperAgentToolFactory] {
        [AnySuperAgentToolFactory(BrowserToolFactory())]
    }
}

// MARK: - Tool Factory

@MainActor
private struct BrowserToolFactory: SuperAgentToolFactory {
    let id: String = "browser.screenshot.factory"
    let order: Int = 0

    func makeTools(env: SuperAgentToolEnvironment) -> [SuperAgentTool] {
        [BrowserScreenshotTool()]
    }
}
