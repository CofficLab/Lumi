import Foundation
import LumiKernel
import SuperLogKit

/// Add Project Tool
struct AddProjectTool: AgentToolInfo, Sendable, SuperLog {
    nonisolated static let emoji = "➕"
    nonisolated static let verbose = false

    var name: String { "add_project" }
    var description: String { "Add an existing local directory to the projects list without switching the current project." }

    @MainActor
    func execute(arguments: [String: Any], viewModel: ProjectsViewModel?) -> String {
        guard let viewModel else {
            return "Error: Projects view model is not available."
        }

        guard let path = arguments["path"] as? String else {
            return "Error: Missing required parameter `path`."
        }

        do {
            let project = try viewModel.add(path: path, select: false)
            return successMessage(project: project, projects: viewModel.projects)
        } catch {
            return "Error: \(error.localizedDescription)"
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