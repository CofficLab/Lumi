import Foundation
import LumiCoreAgentTool
import LumiCoreMessage
import LumiKernel
import SuperLogKit

/// Get Current Project Tool
struct GetCurrentProjectTool: LumiAgentTool, SuperLog {
    nonisolated static let emoji = "📍"
    nonisolated static let verbose = false

    static let info = LumiAgentToolInfo(
        id: "get_current_project",
        displayName: "Get Current Project",
        description: "Get the currently selected project name and path. Returns empty status if no project is selected."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let viewModel = await MainActor.run(body: { ProjectsToolRuntimeBridge.viewModel }) else {
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