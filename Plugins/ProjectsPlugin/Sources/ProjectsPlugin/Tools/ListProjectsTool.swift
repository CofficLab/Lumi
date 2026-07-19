import Foundation
import LumiKernel
import SuperLogKit

/// List Projects Tool
struct ListProjectsTool: AgentToolInfo, Sendable, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose = false

    var name: String { "list_projects" }
    var description: String { "List saved projects with project names, paths, and last used times." }

    private let maxLimit = 500

    @MainActor
    func execute(arguments: [String: Any], viewModel: ProjectsViewModel?) -> String {
        let limit = min((arguments["limit"] as? Int) ?? 5, maxLimit)

        guard let viewModel else {
            return "Error: Projects view model is not available."
        }

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

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}