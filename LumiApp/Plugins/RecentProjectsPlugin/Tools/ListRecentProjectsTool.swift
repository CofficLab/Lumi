import Foundation
import AgentToolKit

/// 列出最近项目工具
struct ListRecentProjectsTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = false
    let name = "list_recent_projects"
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "获取最近使用的项目列表。返回项目名称、路径和最后使用时间。适合了解用户最近在处理哪些项目。"
        case .english:
            return "Get a list of recently used projects. Returns project names, paths, and last used times. Useful for understanding what projects the user has been working on."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "limit": [
                    "type": "integer",
                    "description": "Maximum number of projects to return (default: 5, max: 500)",
                ],
            ],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        let limit = min((arguments["limit"]?.value as? Int) ?? 5, 500)

        if Self.verbose {
            if RecentProjectsPlugin.verbose {
                            RecentProjectsPlugin.logger.info("\(Self.t)Listing recent projects, limit: \(limit)")
            }
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
