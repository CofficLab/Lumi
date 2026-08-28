import KitAgentTool
import Foundation

/// List Projects Tool
public struct ListProjectsTool: SuperAgentTool {
    public let name = "list_projects"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "List saved projects with project names, paths, and last used times."
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

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "List projects"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .safe
    }

    private let maxLimit = 500

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let limit = min(ProjectToolSupport.int(arguments, "limit") ?? 5, maxLimit)

        guard let viewModel = await MainActor.run(body: { ProjectsRuntime.viewModel }) else {
            return "Error: Projects view model is not available."
        }

        return await MainActor.run {
            let projects = Array(viewModel.projects.prefix(limit))

            guard !projects.isEmpty else {
                return "No projects found."
            }

            var output = "## Projects\n\n"
            for (index, project) in projects.enumerated() {
                output += "\(index + 1). **\(project.name)**"
                if viewModel.currentProject?.path == project.path {
                    output += " (current)"
                }
                output += "\n"
                output += "   Path: `\(project.path)`\n"
                output += "   Last used: \(Self.formatDate(project.lastUsed))\n\n"
            }

            return output
        }
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
