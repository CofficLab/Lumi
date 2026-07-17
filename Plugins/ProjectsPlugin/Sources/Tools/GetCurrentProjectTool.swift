import Foundation
import LumiCoreKit
import SuperLogKit

struct GetCurrentProjectTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📍"
    public nonisolated static let verbose: Bool = true

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
        if Self.verbose {
            if ProjectsPlugin.verbose {
                ProjectsPlugin.logger.info("\(Self.t)执行 get_current_project")
            }
        }

        return await MainActor.run {
            guard let viewModel = ProjectsPlugin.viewModel,
                  let project = viewModel.currentProject else {
                if Self.verbose {
                    if ProjectsPlugin.verbose {
                        ProjectsPlugin.logger.warning("\(Self.t)⚠️ get_current_project 返回空：当前无选中项目")
                    }
                }

                return """
                ## Current Project Status

                **Status**: No project selected
                """
            }

            if Self.verbose {
                if ProjectsPlugin.verbose {
                    ProjectsPlugin.logger.info("\(Self.t)✅ 当前项目：\(project.name) (\(project.path))")
                }
            }

            return """
            ## Current Project Info

            **Project Name**: \(project.name)

            **Project Path**: \(project.path)
            """
        }
    }
}
