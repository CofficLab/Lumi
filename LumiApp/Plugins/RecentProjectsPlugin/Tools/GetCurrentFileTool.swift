import Foundation
import MagicKit

/// 获取当前文件工具
struct GetCurrentFileTool: AgentTool, SuperLog {
    nonisolated static let emoji = "📄"
    nonisolated static let verbose: Bool = true
    let name = "get_current_file"
    let description = "获取当前选中的文件信息，包括文件路径和最后选择时间。如果没有选择文件，返回空信息。"

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
            RecentProjectsPlugin.logger.info("\(Self.t)获取当前文件")
        }

        let store = RecentProjectsStore()
        guard let fileInfo = store.getCurrentFile() else {
            return """
            ## 当前文件状态
            
            **状态**: 未选择文件
            
            使用 `set_current_file` 工具来选择一个文件。
            """
        }

        let fileName = URL(fileURLWithPath: fileInfo.path).lastPathComponent

        return """
        ## 当前文件信息
        
        **文件名称**: \(fileName)
        
        **文件路径**: \(fileInfo.path)
        
        **最后选择**: \(formatDate(fileInfo.lastSelected))
        """
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}