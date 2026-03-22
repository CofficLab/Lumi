import Foundation
import MagicKit

/// Shell 命令执行工具
///
/// 允许 AI 助手执行 Shell 命令。
///
/// 架构说明：
/// - ShellTool 作为工具定义，遵循 AgentTool 协议
/// - 实际的 Shell 执行由插件内的 ShellService.shared 单例处理
/// - 内核只认识 Tool 抽象，不关心具体实现细节
struct ShellTool: AgentTool, SuperLog {
    nonisolated static let emoji = "💻"
    nonisolated static let verbose = false

    let name = "run_command"
    let description = "Execute a shell command in terminal. Use this to run build commands, git commands, or other system tools."

    var inputSchema: [String: Any] {
        return [
            "type": "object",
            "properties": [
                "command": [
                    "type": "string",
                    "description": "The command string to execute (e.g., 'git status')"
                ]
            ],
            "required": ["command"]
        ]
    }

    init() {}

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        guard let command = arguments["command"]?.value as? String else {
            return .high
        }
        return CommandRiskEvaluator.evaluate(command: command)
    }

    @MainActor
    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let command = arguments["command"]?.value as? String else {
            throw ShellToolError.missingCommand
        }

        let riskLevel = CommandRiskEvaluator.evaluate(command: command)
        if Self.verbose {
            AgentCoreToolsPlugin.logger.info("\(self.t)\(riskLevel.displayName) \n \(command)")
        }

        let shellService = ShellService.shared
        do {
            return try await shellService.execute(command)
        } catch {
            AgentCoreToolsPlugin.logger.error("\(self.t)Shell execution failed: \(error.localizedDescription)")
            throw ShellToolError.executionFailed(underlying: error)
        }
    }
}

/// Shell 工具执行失败时抛出的错误，便于调用方区分成功与失败并做 UI 展示。
enum ShellToolError: Error, LocalizedError {
    case missingCommand
    case executionFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .missingCommand:
            return "Missing 'command' argument"
        case .executionFailed(let error):
            return error.localizedDescription
        }
    }
}