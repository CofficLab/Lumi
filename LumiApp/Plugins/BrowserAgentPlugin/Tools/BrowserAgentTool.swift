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
        // 注意：macOS GUI 应用的 PATH 可能不包含 /opt/homebrew/bin 等 Homebrew 路径，
        // 所以先尝试 which，找不到再逐一检查常见安装路径
        let agentBrowserPath = await Self.findAgentBrowser()
        guard let agentBrowserPath else {
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
                executable: agentBrowserPath,
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

    // MARK: - Command Discovery

    /// agent-browser 的常见安装路径（macOS GUI 应用 PATH 可能不包含这些目录）
    private static let candidatePaths = [
        "/opt/homebrew/bin/agent-browser",     // Apple Silicon Homebrew
        "/usr/local/bin/agent-browser",         // Intel Homebrew
        "/usr/bin/agent-browser",               // 系统级安装
        "/Users/\(NSUserName())/.volta/bin/agent-browser", // Volta (npm 全局)
    ]

    /// 查找 agent-browser 可执行文件路径
    ///
    /// 先尝试 `which`（在应用 PATH 环境中查找），找不到则逐一检查常见安装路径。
    /// 最后尝试通过 shell 登录获取用户的完整 PATH 来查找。
    private static func findAgentBrowser() async -> String? {
        // 1. 先尝试 which（应用进程的 PATH）
        if let path = await ShellExecutor.findCommand("agent-browser") {
            return path
        }

        // 2. 逐一检查常见路径
        for path in candidatePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // 3. 通过登录 shell 获取用户的完整 PATH，再尝试 which
        // macOS GUI 应用继承 launchd 的环境，PATH 通常只有 /usr/bin:/bin:/usr/sbin:/sbin
        // 而用户的 shell 配置（.zshrc/.zprofile）中的 PATH 不会被加载
        if let path = await findCommandViaLoginShell("agent-browser") {
            return path
        }

        return nil
    }

    /// 通过登录 shell 获取用户完整 PATH 来查找命令
    private static func findCommandViaLoginShell(_ command: String) async -> String? {
        do {
            let result = try await ShellExecutor.execute(
                executable: "/bin/zsh",
                arguments: ["-l", "-c", "which \(command)"],
                options: .init(timeout: 5, throwsOnError: false)
            )
            let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return result.isSuccess && !path.isEmpty ? path : nil
        } catch {
            return nil
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
