import Foundation
import MagicKit
import OSLog
import SwiftUI

/// Shell 命令执行工具
///
/// 允许 AI 助手执行 Shell 命令。
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

        let shellService = ShellService()
        do {
            let output = try await shellService.execute(command)
            return output
        } catch {
            return "Error executing command: \(error.localizedDescription)"
        }
    }
}

