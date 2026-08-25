import KitAgentTool
import Foundation

/// Get Current Project Tool
public struct GetCurrentProjectTool: SuperAgentTool {
    public let name = "get_current_project"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Get the currently selected project name and path. Returns empty status if no project is selected."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": [String: Any]()]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Get current project"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .safe
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let viewModel = await MainActor.run(body: { ProjectsRuntime.viewModel }) else {
            return """
            ## Current Project Status

            **Status**: No project selected
            """
        }

        return await MainActor.run {
            guard let project = viewModel.currentProject else {
                return """
                ## Current Project Status

                **Status**: No project selected
                """
            }

            return """
            ## Current Project Info

            **Project Name**: \(project.name)

            **Project Path**: \(project.path)
            """
        }
    }
}
