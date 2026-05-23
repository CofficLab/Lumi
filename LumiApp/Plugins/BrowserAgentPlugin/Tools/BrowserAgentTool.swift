import Foundation
import AgentToolKit
import os
import ShellKit

/// 浏览器自动化工具
///
/// 基于 agent-browser CLI 提供浏览器操作能力，
/// 包括网页导航、元素交互、截图、获取页面快照等。
struct BrowserAgentTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose: Bool = false

    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.browser-agent.tool")

    let name = "browser_agent"

    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return """
使用 agent-browser 进行浏览器自动化操作。

主要功能：
- 网页导航和交互（打开 URL、点击、输入、滚动）
- 获取页面快照（Accessibility Tree）
- 截图和 PDF 导出
- 表单填写和提交
- JavaScript 执行
- Cookie 和存储管理

典型工作流：
1. 使用 `open <url>` 打开网页
2. 使用 `snapshot` 获取页面结构
3. 使用 `click @ref` 或 `fill @ref "text"` 交互
4. 使用 `screenshot` 截图

注意：需要用户已安装 agent-browser CLI 工具。
"""
        case .english:
            return """
Browser automation using agent-browser CLI.

Capabilities:
- Navigate and interact with web pages (open URL, click, type, scroll)
- Get page snapshots (Accessibility Tree)
- Take screenshots and export PDFs
- Fill and submit forms
- Execute JavaScript
- Manage cookies and storage

Typical workflow:
1. Open page with `open <url>`
2. Get structure with `snapshot`
3. Interact with `click @ref` or `fill @ref "text"`
4. Capture with `screenshot`

Note: Requires agent-browser CLI to be installed.
"""
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "command": [
                    "type": "string",
                    "description": "The agent-browser command to execute (e.g., 'open https://example.com', 'snapshot', 'click @e1', 'screenshot')"
                ],
                "timeout": [
                    "type": "integer",
                    "description": "Command timeout in seconds (default: 30)"
                ]
            ],
            "required": ["command"]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await executeCommand(arguments: arguments, context: nil)
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        return try await executeCommand(arguments: arguments, context: context)
    }

    // MARK: - Implementation

    private func executeCommand(arguments: [String: ToolArgument], context: ToolExecutionContext?) async throws -> String {
        guard let command = arguments["command"]?.value as? String else {
            return "Error: Missing required 'command' parameter"
        }

        let timeout = arguments["timeout"]?.value as? Int ?? 30

        if Self.verbose {
            Self.logger.info("\(self.t)🌐 Executing: agent-browser \(command)")
        }

        // 检测 agent-browser 是否可用
        let agentBrowserPath = await ShellExecutor.findCommand("agent-browser")
        guard agentBrowserPath != nil else {
            return Self.installationGuide
        }

        do {
            try context?.checkCancellation()

            let args = command.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            let options = ShellOptions(
                timeout: TimeInterval(timeout),
                throwsOnError: false
            )

            let result = try await ShellExecutor.execute(
                executable: "agent-browser",
                arguments: args,
                options: options
            )

            try context?.checkCancellation()

            if Self.verbose {
                Self.logger.info("\(self.t)✅ Command completed (exit: \(result.exitCode))")
            }

            if result.exitCode == 0 {
                return result.stdout.isEmpty ? "Command completed successfully" : result.stdout
            } else {
                let errorMsg = result.stderr.isEmpty ? "Command failed with exit code \(result.exitCode)" : result.stderr
                return "Error: \(errorMsg)"
            }
        } catch let error as CancellationError {
            throw error
        } catch {
            Self.logger.error("\(self.t)❌ Command failed: \(error.localizedDescription)")
            return "Error: \(error.localizedDescription)"
        }
    }

    /// 安装指南
    private static var installationGuide: String {
        """
        Error: agent-browser is not installed on this system.

        To install agent-browser, run one of the following commands:

        **Using npm (recommended):**
        ```
        npm install -g agent-browser
        ```

        **Using Homebrew (macOS):**
        ```
        brew install agent-browser
        ```

        **Using Cargo (Rust):**
        ```
        cargo install agent-browser
        ```

        **Quick start (no install):**
        ```
        npx agent-browser open example.com
        ```

        After installation, run the following to download Chrome (first time):
        ```
        agent-browser install
        ```

        For more information, visit: https://github.com/vercel-labs/agent-browser
        """
    }
}
