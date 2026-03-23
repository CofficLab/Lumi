import Foundation
import MagicKit

/// 获取最近项目列表工具
struct ListRecentProjectsTool: AgentTool, SuperLog {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose = false

    let name = "list_recent_projects"
    let description = "Get a list of recently used projects. Returns project names, paths, and last used times. Useful for understanding what projects the user has been working on."

    var inputSchema: [String: Any] {
        return [
            "type": "object",
            "properties": [
                "limit": [
                    "type": "integer",
                    "description": "Maximum number of projects to return (default: 5, max: 20)"
                ]
            ],
            "required": []
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let limit = min(arguments["limit"]?.value as? Int ?? 5, 20)

        let projects = RecentProjectsStore().loadProjects()

        let limitedProjects = projects.prefix(limit)

        if limitedProjects.isEmpty {
            return "No recent projects found."
        }

        var result = "Recent projects:\n\n"
        for (index, project) in limitedProjects.enumerated() {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let lastUsed = formatter.string(from: project.lastUsed)

            result += "\(index + 1). **\(project.name)**\n"
            result += "   Path: \(project.path)\n"
            result += "   Last used: \(lastUsed)\n\n"
        }

        return result
    }
}