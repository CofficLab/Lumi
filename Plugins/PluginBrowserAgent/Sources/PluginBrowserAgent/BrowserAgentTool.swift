import AgentToolKit
import Foundation
import ShellKit
import SuperLogKit
import os

/// 浏览器自动化工具。
///
/// 基于 agent-browser CLI 提供浏览器操作能力，
/// 包括网页导航、元素交互、截图、获取页面快照等。
public struct BrowserAgentTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "🌐"
    public nonisolated static let verbose: Bool = true

    private nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.browser-agent.tool")

    public let name = "browser_agent"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
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

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "command": [
                    "type": "string",
                    "description": "The agent-browser command to execute (e.g., 'open https://example.com', 'snapshot', 'click @e1', 'screenshot')",
                ],
                "timeout": [
                    "type": "integer",
                    "description": "Command timeout in seconds (default: 30, range: 1-300)",
                    "minimum": 1,
                    "maximum": 300,
                ],
            ],
            "required": ["command"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "浏览器自动化"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        return try await executeCommand(arguments: arguments, context: context)
    }

    // MARK: - Implementation

    private func executeCommand(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let command = arguments["command"]?.value as? String else {
            return "Error: Missing required 'command' parameter"
        }

        let timeout = Self.normalizedTimeout(arguments["timeout"]?.value as? Int)

        if Self.verbose {
            Self.logger.info("\(self.t)🌐 Executing: agent-browser \(command)")
        }

        let agentBrowserPath = await Self.findAgentBrowser()
        guard let agentBrowserPath else {
            return Self.installationGuide
        }

        do {
            try context.checkCancellation()

            guard let args = Self.parseCommandArguments(command), !args.isEmpty else {
                return "Error: Command contains an unterminated quote or no arguments"
            }
            let options = ShellOptions(
                timeout: TimeInterval(timeout),
                throwsOnError: false
            )

            let result = try await ShellExecutor.execute(
                executable: agentBrowserPath,
                arguments: args,
                options: options
            )

            try context.checkCancellation()

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

    static func normalizedTimeout(_ rawTimeout: Int?) -> TimeInterval {
        TimeInterval(min(max(rawTimeout ?? 30, 1), 300))
    }

    static func parseCommandArguments(_ command: String) -> [String]? {
        var args: [String] = []
        var current = ""
        var activeQuote: Character?
        var isEscaping = false
        var hasCurrentArgument = false

        for character in command {
            if isEscaping {
                current.append(character)
                hasCurrentArgument = true
                isEscaping = false
                continue
            }

            if character == "\\" {
                isEscaping = true
                hasCurrentArgument = true
                continue
            }

            if let quote = activeQuote {
                if character == quote {
                    activeQuote = nil
                } else {
                    current.append(character)
                    hasCurrentArgument = true
                }
                continue
            }

            if character == "\"" || character == "'" {
                activeQuote = character
                hasCurrentArgument = true
            } else if character.isWhitespace {
                if hasCurrentArgument {
                    args.append(current)
                    current = ""
                    hasCurrentArgument = false
                }
            } else {
                current.append(character)
                hasCurrentArgument = true
            }
        }

        if activeQuote != nil {
            return nil
        }

        if isEscaping {
            current.append("\\")
        }

        if hasCurrentArgument {
            args.append(current)
        }

        return args
    }

    // MARK: - Command Discovery

    /// agent-browser 的常见安装路径（macOS GUI 应用 PATH 可能不包含这些目录）
    private static let candidatePaths = [
        "/opt/homebrew/bin/agent-browser",
        "/usr/local/bin/agent-browser",
        "/usr/bin/agent-browser",
        "/Users/\(NSUserName())/.volta/bin/agent-browser",
    ]

    /// 查找 agent-browser 可执行文件路径
    private static func findAgentBrowser() async -> String? {
        if let path = await ShellExecutor.findCommand("agent-browser") {
            return path
        }

        for path in candidatePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

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
