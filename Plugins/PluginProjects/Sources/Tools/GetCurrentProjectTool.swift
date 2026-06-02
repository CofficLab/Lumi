import Foundation
import SuperLogKit
import AgentToolKit
import LumiCoreKit

/// 获取当前项目工具
public struct GetCurrentProjectTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📁"
    public nonisolated static let verbose: Bool = true
    public let name = "get_current_project"
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "获取当前选中项目的信息，包括项目名称和路径。如果没有选中项目，则返回空信息。"
        case .english:
            return "Get the current selected project information, including project name and path. Returns empty info if no project is selected."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [:]
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {        "获取当前项目"    }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        if Self.verbose {
            if ProjectsPlugin.verbose {
                            ProjectsPlugin.logger.info("\(Self.t)Getting current project")
            }
        }

        let projectPath = context.currentProjectPath

        guard let projectPath, !projectPath.isEmpty else {
            return """
            ## Current Project Status

            **Status**: No project selected

            Use the `set_current_project` tool to select a project.
            """
        }

        let projectName = URL(fileURLWithPath: projectPath).lastPathComponent

        return """
        ## Current Project Info

        **Project Name**: \(projectName)

        **Project Path**: \(projectPath)
        """
    }
}
