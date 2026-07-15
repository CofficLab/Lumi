import Foundation
import LumiCoreKit

struct GetCurrentProjectTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "get_current_project",
        displayName: LumiPluginLocalization.string("Get Current Project", bundle: .module),
        description: LumiPluginLocalization.string("Get the currently selected project name and path. Returns empty status if no project is selected.", bundle: .module)
    )

    init() {}

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "获取当前项目"
    }

    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .safe
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        await MainActor.run {
            guard let viewModel = ProjectsPlugin.viewModel,
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
}
