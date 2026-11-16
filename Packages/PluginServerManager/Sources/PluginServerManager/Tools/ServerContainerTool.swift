import Foundation
import KitAgentTool

/// 查看 / 操作远端服务器的 Docker 容器。
///
/// `list` 只读（低风险）；`start` / `stop` / `restart` 会改变服务器状态，
/// 高风险且必须用户显式批准。
struct ServerContainerTool: SuperAgentTool {
    private let backend: ServerBackend

    init(backend: ServerBackend) {
        self.backend = backend
    }

    var name: String { "server_container" }

    func description(for language: LanguagePreference) -> String {
        "List Docker containers on a configured remote server, or start/stop/restart a container by name. Listing is read-only; start/stop/restart change server state and require explicit user approval."
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "server": [
                    "type": "string",
                    "description": "Server name (as shown by server_list) or its UUID.",
                ],
                "action": [
                    "type": "string",
                    "enum": ["list", "start", "stop", "restart"],
                    "description": "Defaults to 'list'.",
                ],
                "name": [
                    "type": "string",
                    "description": "Container name. Required for start/stop/restart.",
                ],
            ],
            "required": ["server"],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        Self.action(arguments) == "list" ? .low : .high
    }

    func requiresExplicitApproval(arguments: [String: ToolArgument]) -> Bool {
        Self.action(arguments) != "list"
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let key = arguments["server"]?.value as? String ?? "?"
        let action = Self.action(arguments)
        if action == "list" {
            return "查看服务器 \(key) 的容器列表"
        }
        let name = arguments["name"]?.value as? String ?? "?"
        return "在服务器 \(key) 上 \(action) 容器 \(name)"
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
        let action = Self.action(arguments)
        do {
            if action == "list" {
                let containers = try await backend.containers(id: config.id)
                guard !containers.isEmpty else {
                    return "No containers found."
                }
                var lines = [
                    "## Containers on \(config.name)",
                    "",
                    "| Name | Image | State | Status |",
                    "| --- | --- | --- | --- |",
                ]
                for container in containers {
                    lines.append("| \(container.name) | \(container.image) | \(container.state.rawValue) | \(container.status) |")
                }
                return lines.joined(separator: "\n")
            }

            guard let containerAction = ServerContainerAction(rawValue: action) else {
                throw ToolExecutionError.executionFailed(
                    toolName: name,
                    reason: "Invalid action '\(action)'. Use list, start, stop or restart."
                )
            }
            guard let containerName = arguments["name"]?.value as? String, !containerName.isEmpty else {
                throw ToolExecutionError.executionFailed(
                    toolName: name,
                    reason: "Missing required argument 'name' for action '\(action)'."
                )
            }
            try await backend.containerAction(id: config.id, name: containerName, action: containerAction)
            return "Container '\(containerName)' \(action) completed on \(config.name)."
        } catch let error as ToolExecutionError {
            throw error
        } catch {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: error.localizedDescription
            )
        }
    }

    private static func action(_ arguments: [String: ToolArgument]) -> String {
        let raw = (arguments["action"]?.value as? String ?? "list")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return raw.isEmpty ? "list" : raw
    }
}