import Foundation
import MagicKit

/// 获取当前文件工具
struct GetCurrentFileTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📄"
    nonisolated static let verbose: Bool = true
    let name = "get_current_file"
    let description = "Get the current selected file information, including file path and last selection time. Returns empty info if no file is selected."

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
            BreadcrumbPlugin.logger.info("\(Self.t)Getting current file")
        }

        let store = RecentProjectsStore()
        guard let fileInfo = store.getCurrentFile() else {
            return """
            ## Current File Status
            
            **Status**: No file selected
            
            Use the `set_current_file` tool to select a file.
            """
        }

        let fileName = URL(fileURLWithPath: fileInfo.path).lastPathComponent

        return """
        ## Current File Info
        
        **File Name**: \(fileName)
        
        **File Path**: \(fileInfo.path)
        
        **Last Selected**: \(formatDate(fileInfo.lastSelected))
        """
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}