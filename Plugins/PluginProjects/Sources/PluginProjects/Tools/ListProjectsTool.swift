import Foundation
import SuperLogKit
import AgentToolKit

/// 列出项目工具
public struct ListProjectsTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = true
    public let name = "list_projects"
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "获取项目列表。返回项目名称、路径和最后使用时间。适合了解用户最近在处理哪些项目。"
        case .english:
            return "Get a list of projects. Returns project names, paths, and last used times. Useful for understanding what projects the user has been working on."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
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

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {        "列出项目"    }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        let limit = Self.normalizedLimit(arguments["limit"]?.value)

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

    static func normalizedLimit(_ value: Any?) -> Int {
        let requested: Int
        if let int = value as? Int {
            requested = int
        } else if let double = value as? Double {
            requested = Int(double)
        } else if let string = value as? String, let int = Int(string) {
            requested = int
        } else {
            requested = 5
        }

        return min(max(requested, 1), 500)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
