import Foundation
import MagicKit

/// 获取当前文件工具
///
/// 基于 EditorTabStripStore 的 activeTabPath 获取当前活跃文件。
struct GetCurrentFileTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📄"
    nonisolated static let verbose: Bool = true
    let name = "get_current_file"
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "Get the current selected file information, including file path and last selection time. Returns empty info if no file is selected."
        case .english:
            return "Get the current selected file information, including file path and last selection time. Returns empty info if no file is selected."
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
        // 获取当前项目路径
        let projectStore = RecentProjectsStore()
        guard let project = projectStore.getCurrentProject() else {
            return """
            ## Current File Status

            **Status**: No project selected

            Use the `set_current_project` tool to select a project first.
            """
        }

        let store = EditorTabStripStore.shared
        guard let fileInfo = store.getCurrentFilePath(forProject: project.path) else {
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
