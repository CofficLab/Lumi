import Foundation
import MagicKit

/// 获取当前项目工具
struct GetCurrentProjectTool: AgentTool, SuperLog {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose = true

    let name = "get_current_project"
    let description = "获取当前选中的项目信息，包括项目名称和路径。如果没有选择项目，返回空信息。"

    var inputSchema: [String: Any] {
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
            AgentRecentProjectsPlugin.logger.info("\(Self.t)获取当前项目")
        }

        let store = RecentProjectsStore()
        guard let project = store.getCurrentProject() else {
            return """
            ## 当前项目状态
            
            **状态**: 未选择项目
            
            使用 `set_current_project` 工具来选择一个项目。
            """
        }

        return """
        ## 当前项目信息
        
        **项目名称**: \(project.name)
        
        **项目路径**: \(project.path)
        
        **最后使用**: \(formatDate(project.lastUsed))
        """
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}