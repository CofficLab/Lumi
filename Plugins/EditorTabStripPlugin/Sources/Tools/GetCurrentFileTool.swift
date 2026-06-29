import Foundation
import SuperLogKit
import AgentToolKit
import os

/// 获取当前文件工具
///
/// 基于 StripStore 的 activeTabPath 获取当前活跃文件。
public struct GetCurrentFileTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📄"
    public nonisolated static let verbose: Bool = true
    public let name = "get_current_file"
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "获取当前选中文件的信息，包括文件路径和最后选择时间。如果没有选中文件，则返回空信息。"
        case .english:
            return "Get the current selected file information, including file path and last selection time. Returns empty info if no file is selected."
        }
    }

    public init() {}

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [:]
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {        "获取当前文件"    }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        let projectPath = context.currentProjectPath

        guard let projectPath else {
            return """
            ## Current File Status

            **Status**: No project selected

            Use the `set_current_project` tool to select a project first.
            """
        }

        let store = StripStore.shared
        guard let fileInfo = store.getCurrentFilePath(forProject: projectPath) else {
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
