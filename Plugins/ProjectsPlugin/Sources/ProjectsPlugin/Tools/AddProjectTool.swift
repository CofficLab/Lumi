import Foundation
import LumiCoreAgentTool
import LumiCoreMessage
import LumiKernel
import SuperLogKit

/// Add Project Tool
struct AddProjectTool: LumiAgentTool, SuperLog {
    nonisolated static let emoji = "➕"
    nonisolated static let verbose = false

    static let info = LumiAgentToolInfo(
        id: "add_project",
        displayName: "Add Project",
        description: "Add an existing local directory to the projects list without switching the current project."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("The path to the project directory to add")
                ])
            ]),
            "required": .array([.string("path")])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let viewModel = await MainActor.run(body: { ProjectsToolRuntimeBridge.viewModel }) else {
            return "Error: Projects view model is not available."
        }

        guard let path = arguments.string("path") else {
            return "Error: Missing required parameter `path`."
        }

        return await MainActor.run {
            do {
                let project = try viewModel.add(path: path, select: false)
                return successMessage(project: project, projects: viewModel.projects)
            } catch {
                return "Error: \(error.localizedDescription)"
            }
        }
    }

    private func successMessage(project: ProjectEntry, projects: [ProjectEntry]) -> String {
        var output = """
        Successfully added project.

        **Project Name**: \(project.name)

        **Project Path**: \(project.path)

        ## Projects (\(projects.count) total)

        """

        for (index, project) in projects.prefix(5).enumerated() {
            output += "\(index + 1). **\(project.name)**\n"
            output += "   Path: `\(project.path)`\n\n"
        }

        return output
    }
}