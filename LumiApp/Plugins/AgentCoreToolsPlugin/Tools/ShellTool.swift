import Foundation
import AgentToolKit

/// Shell 命令执行工具
///
/// 允许 AI 助手执行 Shell 命令。
///
/// 架构说明：
/// - ShellTool 作为工具定义，遵循 SuperAgentTool 协议
/// - 实际的 Shell 执行由插件内的 ShellService.shared 单例处理
/// - 内核只认识 Tool 抽象，不关心具体实现细节
struct ShellTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "💻"
    nonisolated static let verbose: Bool = true
    let name = "run_command"

    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "在终端中执行 Shell 命令。可用于运行构建命令、git 命令或其他系统工具。"
        case .english:
            return "Execute a shell command in terminal. Use this to run build commands, git commands, or other system tools."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let commandDescription: String
        let displayDesc: String
        switch language {
        case .chinese:
            commandDescription = "要执行的命令字符串（如 'git status'）"
            displayDesc = "向用户展示当前操作描述，如：正在执行 git status"
        case .english:
            commandDescription = "The command string to execute (e.g., 'git status')"
            displayDesc = "A short description shown to the user, e.g. \"Running git status\""
        }
        return [
            "type": "object",
            "properties": [
                "command": [
                    "type": "string",
                    "description": commandDescription
                ],
                "display_name": [
                    "type": "string",
                    "description": displayDesc
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

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let command = arguments["command"]?.value as? String else { return "执行命令" }
        let preview = command.count > 40 ? String(command.prefix(40)) + "…" : command
        return "执行 \(preview)"
    }

    @MainActor
    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        return try await executeShell(arguments: arguments, context: context)
    }

    @MainActor
    private func executeShell(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let command = arguments["command"]?.value as? String else {
            throw ShellToolError.missingCommand
        }

        let riskLevel = CommandRiskEvaluator.evaluate(command: command)
        if Self.verbose {
            AgentCoreToolsPlugin.logger.info("\(self.t)\(riskLevel.displayName) \n \(command.max(count: 40))")
        }

        let shellService = ShellService.shared
        do {
            try context.checkCancellation()
            let result = try await shellService.execute(command)
            try context.checkCancellation()
            return result
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
