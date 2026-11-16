import Foundation
import KitAgentTool

/// 探测一台服务器的基本状态（系统 / 负载 / 内存 / 磁盘）。
///
/// 通过 SSH 执行固定的只读脚本，不接受自由命令输入；
/// 需要网络访问，风险等级为 medium。
struct ServerStatusTool: SuperAgentTool {
    private let backend: ServerBackend

    init(backend: ServerBackend) {
        self.backend = backend
    }

    var name: String { "server_status" }

    func description(for language: LanguagePreference) -> String {
        "Probe a configured remote server over SSH and return its OS, uptime, CPU, load, memory and disk usage. Read-only on the server; requires network access."
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "server": [
                    "type": "string",
                    "description": "Server name (as shown by server_list) or its UUID.",
                ],
            ],
            "required": ["server"],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let key = arguments["server"]?.value as? String ?? "?"
        return "探测服务器 \(key) 的状态"
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
        do {
            let metrics = try await backend.metrics(id: config.id)
            return Self.render(metrics: metrics, config: config)
        } catch let error as ToolExecutionError {
            throw error
        } catch {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: error.localizedDescription
            )
        }
    }

    static func render(metrics: ServerMetrics, config: ServerConfig) -> String {
        func percent(_ value: Double?) -> String {
            value.map { String(format: "%.1f%%", $0) } ?? "n/a"
        }
        func bytes(_ value: Int64?) -> String {
            guard let value else { return "n/a" }
            return ByteCountFormatter.string(fromByteCount: value, countStyle: .memory)
        }
        var lines = [
            "## \(config.name) (\(config.destination))",
            "",
            "- OS: \(metrics.os ?? "n/a")",
            "- Hostname: \(metrics.hostname ?? "n/a")",
            "- Uptime: \(metrics.uptime ?? "n/a")",
            "- CPU: \(percent(metrics.cpuPercent))" + (metrics.cores.map { " (\($0) cores)" } ?? ""),
            "- Memory: \(percent(metrics.memPercent)) (\(bytes(metrics.memUsedBytes)) / \(bytes(metrics.memTotalBytes)))",
            "- Disk (/): \(percent(metrics.diskPercent)) (\(bytes(metrics.diskUsedBytes)) / \(bytes(metrics.diskTotalBytes)))",
        ]
        if let load1 = metrics.load1, let load5 = metrics.load5, let load15 = metrics.load15 {
            lines.append(String(format: "- Load average: %.2f %.2f %.2f", load1, load5, load15))
        }
        return lines.joined(separator: "\n")
    }
}