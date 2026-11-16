import Foundation
import KitAgentTool

/// 列出已配置的远程服务器。只读本地配置，不发起网络连接。
struct ServerListTool: SuperAgentTool {
    private let backend: ServerBackend

    init(backend: ServerBackend) {
        self.backend = backend
    }

    var name: String { "server_list" }

    func description(for language: LanguagePreference) -> String {
        "List the remote servers configured in the Server Manager plugin (name, host, user, group). Read-only; does not connect to any server."
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": [:]]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .safe
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "查看已配置的服务器列表"
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let servers = await backend.allServers()
        guard !servers.isEmpty else {
            return "No servers configured."
        }
        var lines = ["| Name | Host | User | Group |", "| --- | --- | --- | --- |"]
        for server in servers {
            lines.append("| \(server.name) | \(server.host):\(server.port) | \(server.user) | \(server.group) |")
        }
        return lines.joined(separator: "\n")
    }
}