import Foundation
import KitAgentTool

/// 在远端服务器上执行命令。
///
/// 风险分级由 `ServerExecRisk` 决定：只读命令 medium，
/// 其余（含任何 shell 元字符）high 且必须用户显式批准。
struct ServerExecTool: SuperAgentTool {
    private let backend: ServerBackend

    init(backend: ServerBackend) {
        self.backend = backend
    }

    var name: String { "server_exec" }

    func description(for language: LanguagePreference) -> String {
        "Run a shell command on a configured remote server over SSH and return its output. Read-only commands are medium risk; anything that may modify the server is high risk and requires explicit user approval."
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "server": [
                    "type": "string",
                    "description": "Server name (as shown by server_list) or its UUID.",
                ],
                "command": [
                    "type": "string",
                    "description": "Shell command to run on the remote server.",
                ],
            ],
            "required": ["server", "command"],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        guard let command = arguments["command"]?.value as? String else { return .high }
        return ServerExecRisk.level(for: command)
    }

    func requiresExplicitApproval(arguments: [String: ToolArgument]) -> Bool {
        permissionRiskLevel(arguments: arguments) == .high
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let key = arguments["server"]?.value as? String ?? "?"
        let command = (arguments["command"]?.value as? String ?? "?")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let short = command.count > 60 ? String(command.prefix(60)) + "…" : command
        return "在服务器 \(key) 上执行：\(short)"
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let key = arguments["server"]?.value as? String, !key.isEmpty else {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "Missing required argument 'server'."
            )
        }
        guard let command = arguments["command"]?.value as? String,
              !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "Missing required argument 'command'."
            )
        }
        guard let config = await backend.server(matching: key) else {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "No server matches '\(key)'. Use server_list to see configured servers."
            )
        }
        do {
            let output = try await backend.exec(id: config.id, command: command)
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return """
            ## \(config.name): \(command.trimmingCharacters(in: .whitespacesAndNewlines))

            ```
            \(trimmed.isEmpty ? "(no output)" : trimmed)
            ```
            """
        } catch let error as ToolExecutionError {
            throw error
        } catch {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: error.localizedDescription
            )
        }
    }
}