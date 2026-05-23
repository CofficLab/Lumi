import Foundation
import AgentToolKit
import os

/// Browser Agent 插件
///
/// 提供浏览器自动化功能，基于 agent-browser CLI 工具。
/// 支持网页导航、元素交互、截图、快照等浏览器操作。
actor BrowserAgentPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.browser-agent")

    /// 日志标识符
    nonisolated static let emoji = "🌐"

    /// 是否启用详细日志
    nonisolated static let verbose: Bool = false

    static let id: String = "BrowserAgent"
    static let displayName: String = String(localized: "Browser Agent", table: "BrowserAgent")
    static let description: String = String(localized: "Browser automation powered by agent-browser CLI", table: "BrowserAgent")
    static let iconName: String = "globe"
    static let isConfigurable: Bool = false
    static var category: PluginCategory { .general }
    static let enable: Bool = true
    static var order: Int { 103 }

    static let shared = BrowserAgentPlugin()

    /// agent-browser 是否可用
    private(set) var isAgentBrowserAvailable: Bool = false

    private init() {}

    func onEnable() async {
        // 检测 agent-browser 是否安装
        isAgentBrowserAvailable = await Self.checkAgentBrowserAvailability()

        if !isAgentBrowserAvailable {
            Self.logger.warning("\(self.t)⚠️ agent-browser is not installed")
        }
    }

    /// 检测 agent-browser 是否可用
    private static func checkAgentBrowserAvailability() async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["agent-browser"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        guard isAgentBrowserAvailable else {
            Self.logger.warning("\(self.t)⚠️ agent-browser not available, tools disabled")
            return []
        }
        return [BrowserAgentTool()]
    }
}
