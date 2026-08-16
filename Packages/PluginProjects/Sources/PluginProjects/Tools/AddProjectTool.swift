import AgentToolKit
import Foundation

/// Add Project Tool
public struct AddProjectTool: SuperAgentTool {
    public let name = "add_project"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Add an existing local directory to the projects list without switching the current project."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "The path to the project directory to add",
                ],
            ],
            "required": ["path"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Add project"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .safe
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let viewModel = await MainActor.run(body: { ProjectsRuntime.viewModel }) else {
            return "Error: Projects view model is not available."
        }

        guard let path = ProjectToolSupport.string(arguments, "path") else {
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
