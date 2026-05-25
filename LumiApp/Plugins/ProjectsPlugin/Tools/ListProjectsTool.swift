import Foundation
import AgentToolKit

/// 列出项目工具
struct ListProjectsTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose: Bool = true
    let name = "list_projects"
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "获取项目列表。返回项目名称、路径和最后使用时间。适合了解用户最近在处理哪些项目。"
        case .english:
            return "Get a list of projects. Returns project names, paths, and last used times. Useful for understanding what projects the user has been working on."
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

    func displayDescription(for arguments: [String: ToolArgument]) -> String {        "列出项目"    }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        let limit = min((arguments["limit"]?.value as? Int) ?? 5, 500)

        if Self.verbose {
            if ProjectsPlugin.verbose {
                            ProjectsPlugin.logger.info("\(Self.t)Listing projects, limit: \(limit)")
            }
        }

        let store = ProjectsStore()
        let projects = Array(store.loadProjects().prefix(limit))

        if projects.isEmpty {
            return "No projects found."
        }

        var output = "## Projects\n\n"
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
