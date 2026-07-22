import Foundation
import LumiKernel
import LumiKernel
import LumiKernel
import SuperLogKit

/// List Projects Tool
struct ListProjectsTool: LumiAgentTool, SuperLog {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose = false

    static let info = LumiAgentToolInfo(
        id: "list_projects",
        displayName: "List Projects",
        description: "List saved projects with project names, paths, and last used times."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum number of projects to return (default: 5, max: 500)")
                ])
            ])
        ])
    }

    private let maxLimit = 500

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let limit = min(arguments.int("limit") ?? 5, maxLimit)

        guard let viewModel = await MainActor.run(body: { ProjectsToolRuntimeBridge.viewModel }) else {
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