import Foundation
import LumiKernel
import SuperLogKit
import os

/// 获取当前文件工具
///
/// 基于 StripStore 的 activeTabPath 获取当前活跃文件。
public struct GetCurrentFileTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📄"
    public nonisolated static let verbose: Bool = true

    public static let info = LumiAgentToolInfo(
        id: "get_current_file",
        displayName: LumiPluginLocalization.string("Get Current File", bundle: .module),
        description: LumiPluginLocalization.string("Get the current selected file information, including file path and last selection time. Returns empty info if no file is selected.", bundle: .module)
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "获取当前文件" }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
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
