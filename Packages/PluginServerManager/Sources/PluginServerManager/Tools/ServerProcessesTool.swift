import Foundation
import KitAgentTool

/// 列出远端服务器上 CPU 占用最高的进程。只读，风险低。
struct ServerProcessesTool: SuperAgentTool {
    private let backend: ServerBackend

    init(backend: ServerBackend) {
        self.backend = backend
    }

    var name: String { "server_processes" }

    func description(for language: LanguagePreference) -> String {
        "List the top processes by CPU usage on a configured remote server (PID, user, CPU%, MEM%, command). Read-only; requires network access."
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "server": [
                    "type": "string",
                    "description": "Server name (as shown by server_list) or its UUID.",
                ],
                "limit": [
                    "type": "integer",
                    "description": "Maximum number of processes to return.",
                    "minimum": 1,
                    "maximum": 20,
                ],
            ],
            "required": ["server"],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let key = arguments["server"]?.value as? String ?? "?"
        return "查看服务器 \(key) 的进程列表"
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let key = arguments["server"]?.value as? String, !key.isEmpty else {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "Missing required argument 'server'."
            )
        }
        guard let config = await backend.server(matching: key) else {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "No server matches '\(key)'. Use server_list to see configured servers."
            )
        }
        let limit = arguments.toolInt("limit", clampedTo: 1...20, default: 20)
        do {
            let processes = try await backend.processes(id: config.id)
            guard !processes.isEmpty else {
                return "No processes found."
            }
            var lines = [
                "## Top processes on \(config.name)",
                "",
                "| PID | User | CPU% | MEM% | Command |",
                "| --- | --- | --- | --- | --- |",
            ]
            for process in processes.prefix(limit) {
                lines.append(String(
                    format: "| %d | %@ | %.1f | %.1f | %@ |",
                    process.pid, process.user, process.cpu, process.mem, process.command
                ))
            }
            return lines.joined(separator: "\n")
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