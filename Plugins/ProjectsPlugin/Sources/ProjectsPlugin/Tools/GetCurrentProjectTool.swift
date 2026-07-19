import Foundation
import LumiKernel
import SuperLogKit

/// Get Current Project Tool
struct GetCurrentProjectTool: AgentToolInfo, Sendable, SuperLog {
    nonisolated static let emoji = "📍"
    nonisolated static let verbose = false

    var name: String { "get_current_project" }
    var description: String { "Get the currently selected project name and path. Returns empty status if no project is selected." }

    @MainActor
    func execute(arguments: [String: Any], viewModel: ProjectsViewModel?) -> String {
        guard let viewModel,
              let project = viewModel.currentProject else {
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