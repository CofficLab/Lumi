import Foundation
import AgentToolKit
import os

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
        let isAvailable = await checkAgentBrowserInstalled()
        guard isAvailable else {
            return Self.installationGuide
        }

        do {
            try context?.checkCancellation()
            let output = try await runAgentBrowser(command: command, timeout: timeout, context: context)
            try context?.checkCancellation()

            if Self.verbose {
                Self.logger.info("\(self.t)✅ Command completed")
            }

            return output
        } catch let error as CancellationError {
            throw error
        } catch {
            Self.logger.error("\(self.t)❌ Command failed: \(error.localizedDescription)")
            return "Error: \(error.localizedDescription)"
        }
    }

    /// 检测 agent-browser 是否已安装
    private func checkAgentBrowserInstalled() async -> Bool {
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

    /// 执行 agent-browser 命令
    @Sendable
    private func runAgentBrowser(command: String, timeout: Int, context: ToolExecutionContext?) async throws -> String {
        try context?.checkCancellation()

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/local/bin/agent-browser")

            // 解析命令参数
            let args = command.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            process.arguments = args

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // 超时处理
            var hasResumed = false
            let lock = NSLock()

            let timeoutTask = Task {
                try await Task.sleep(for: .seconds(timeout))
                lock.lock()
                defer { lock.unlock() }

                guard !hasResumed else { return }
                hasResumed = true

                process.terminate()
                continuation.resume(returning: "Error: Command timed out after \(timeout) seconds")
            }

            // 取消处理
            let cancellationId = context?.onCancel {
                lock.lock()
                defer { lock.unlock() }

                guard !hasResumed else { return }
                hasResumed = true

                timeoutTask.cancel()
                process.terminate()
                continuation.resume(returning: "Error: Command was cancelled")
            }

            process.terminationHandler = { proc in
                lock.lock()
                defer { lock.unlock() }

                guard !hasResumed else { return }
                hasResumed = true

                timeoutTask.cancel()
                context?.removeCancellationHandler(cancellationId)

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if proc.terminationStatus == 0 {
                    continuation.resume(returning: output.isEmpty ? "Command completed successfully" : output)
                } else {
                    let errorMsg = errorOutput.isEmpty ? "Command failed with exit code \(proc.terminationStatus)" : errorOutput
                    continuation.resume(returning: "Error: \(errorMsg)")
                }
            }

            do {
                try process.run()
            } catch {
                lock.lock()
                defer { lock.unlock() }

                guard !hasResumed else { return }
                hasResumed = true

                timeoutTask.cancel()
                context?.removeCancellationHandler(cancellationId)
                continuation.resume(throwing: error)
            }
        }
    }

    /// 安装指南
    private var installationGuide: String {
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
