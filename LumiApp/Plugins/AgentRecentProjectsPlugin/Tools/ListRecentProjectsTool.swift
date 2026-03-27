import Foundation
import MagicKit

/// 列出最近项目工具
struct ListRecentProjectsTool: AgentTool, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose = true

    let name = "list_recent_projects"
    let description = "Get a list of recently used projects. Returns project names, paths, and last used times. Useful for understanding what projects the user has been working on."

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "limit": [
                    "type": "integer",
                    "description": "Maximum number of projects to return (default: 5, max: 20)",
                ],
            ],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let limit = min((arguments["limit"]?.value as? Int) ?? 5, 20)

        if Self.verbose {
            AgentRecentProjectsPlugin.logger.info("\(Self.t)列出最近项目，限制：\(limit)")
        }

        let store = RecentProjectsStore()
        let projects = Array(store.loadProjects().prefix(limit))

        if projects.isEmpty {
            return "No recent projects found."
        }

        var output = "## Recent Projects\n\n"
        for (index, project) in projects.enumerated() {
            output += "\(index + 1). **\(project.name)**\n"
            output += "   Path: `\(project.path)`\n"
            output += "   Last used: \(formatDate(project.lastUsed))\n\n"
        }

        return output
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}