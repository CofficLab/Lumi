import Foundation
import MagicKit

/// 获取当前项目工具
struct GetCurrentProjectTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose: Bool = false
    let name = "get_current_project"
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "获取当前选中项目的信息，包括项目名称和路径。如果没有选中项目，则返回空信息。"
        case .english:
            return "Get the current selected project information, including project name and path. Returns empty info if no project is selected."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [:]
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        if Self.verbose {
            if RecentProjectsPlugin.verbose {
                            RecentProjectsPlugin.logger.info("\(Self.t)Getting current project")
            }
        }

        let store = RecentProjectsStore()
        guard let project = store.getCurrentProject() else {
            return """
            ## Current Project Status
            
            **Status**: No project selected
            
            Use the `set_current_project` tool to select a project.
            """
        }

        return """
        ## Current Project Info
        
        **Project Name**: \(project.name)
        
        **Project Path**: \(project.path)
        
        **Last Used**: \(formatDate(project.lastUsed))
        """
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
