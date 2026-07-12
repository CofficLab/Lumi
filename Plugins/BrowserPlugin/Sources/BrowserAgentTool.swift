import Foundation
import LumiCoreKit
import ShellKit
import SuperLogKit
import os

/// 浏览器自动化工具。
///
/// 基于 agent-browser CLI 提供浏览器操作能力，
/// 包括网页导航、元素交互、截图、获取页面快照等。
public struct BrowserAgentTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🌐"
    public nonisolated static let verbose: Bool = true

    private nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.browser-agent.tool")

    public static let info = LumiAgentToolInfo(
        id: "browser_agent",
        displayName: LumiPluginLocalization.string("Browser Agent", bundle: .module),
        description: LumiPluginLocalization.string(
            "Browser automation using agent-browser CLI. Capabilities: Navigate and interact with web pages (open URL, click, type, scroll), Get page snapshots (Accessibility Tree), Take screenshots and export PDFs, Fill and submit forms, Execute JavaScript, Manage cookies and storage. Note: Requires agent-browser CLI to be installed.",
            bundle: .module
        )
    )
    public static let tags: Set<LumiToolTag> = [.network, .sideEffect]

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "command": .object([
                    "type": .string("string"),
                    "description": .string("The agent-browser command to execute (e.g., 'open https://example.com', 'snapshot', 'click @e1', 'screenshot')")
                ]),
                "timeout": .object([
                    "type": .string("integer"),
                    "description": .string("Command timeout in seconds (default: 30, range: 1-300)"),
                    "minimum": .int(1),
                    "maximum": .int(300)
                ])
            ]),
            "required": .array([.string("command")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "浏览器自动化"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        return try await executeCommand(arguments: arguments, context: context)
    }

    // MARK: - Implementation

    private func executeCommand(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let command = arguments["command"]?.stringValue else {
            return "Error: Missing required 'command' parameter"
        }

        let timeout = Self.normalizedTimeout(arguments["timeout"]?.anyValue)

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

    static func normalizedTimeout(_ value: Any?) -> TimeInterval {
        let requested: Int
        if let int = value as? Int {
            requested = int
        } else if let double = value as? Double {
            requested = Int(double)
        } else if let string = value as? String, let int = Int(string) {
            requested = int
        } else {
            requested = 30
        }

        return TimeInterval(min(max(requested, 1), 300))
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
