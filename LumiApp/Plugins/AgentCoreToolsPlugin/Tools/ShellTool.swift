import Foundation
import MagicKit
import OSLog

/// Shell 命令执行工具
///
/// 允许 AI 助手执行 Shell 命令。
///
/// 架构说明：
/// - ShellTool 作为工具定义，遵循 AgentTool 协议
/// - 实际的 Shell 执行由插件内的 ShellService.shared 单例处理
/// - 内核只认识 Tool 抽象，不关心具体实现细节
struct ShellTool: AgentTool, SuperLog {
    nonisolated static let emoji = "🔧"
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

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel? {
        guard let command = arguments["command"]?.value as? String else {
            return .medium
        }
        return CommandRiskEvaluator.evaluate(command: command)
    }

    @MainActor
    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let command = arguments["command"]?.value as? String else {
            throw NSError(
                domain: "ShellTool",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Missing 'command' argument"]
            )
        }

        let riskLevel = CommandRiskEvaluator.evaluate(command: command)
        if Self.verbose {
            os_log("\(Self.t)👮 \(riskLevel.displayName) \n \(command)")
        }

        // 使用插件内共享的 ShellService 单例
        let shellService = ShellService.shared
        do {
            let output = try await shellService.execute(command)
            return output
        } catch {
            return "Error executing command: \(error.localizedDescription)"
        }
    }
}
