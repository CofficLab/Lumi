import Foundation
import SuperLogKit
import AgentToolKit

/// 设置当前文件工具
///
/// 基于 StripStore 的 activeTabPath 设置当前活跃文件。
public struct SetCurrentFileTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📄"
    public nonisolated static let verbose: Bool = true
    public let name = "set_current_file"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "设置当前选中的文件。需要提供文件路径。此操作会在编辑器标签栏中打开文件并切换界面显示，使其成为用户可见的活动标签页。"
        case .english:
            return "Set the current selected file. Requires a file path. This will open the file in the editor tab strip and switch the UI to display it, making it the active tab visible to the user."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "Absolute path to the file",
                ],
            ],
            "required": ["path"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {        "设置当前文件"    }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let path = arguments["path"]?.value as? String else {
            return "❌ Error: Missing required parameter 'path'"
        }

        // 验证路径是否存在且为文件
        let fm = FileManager.default
        var isDirectory: ObjCBool = false

        guard fm.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return "❌ Error: Path does not exist: \(path)"
        }

        guard !isDirectory.boolValue else {
            return "❌ Error: Path is a directory, not a file: \(path)"
        }

        let projectPath = context.currentProjectPath

        guard let projectPath else {
            return "❌ Error: No project selected. Use `set_current_project` first."
        }

        let fileName = URL(fileURLWithPath: path).lastPathComponent

        // 通过 StripStore 设置当前活跃文件
        let store = StripStore.shared
        store.setCurrentFilePath(path: path, forProject: projectPath)

        // 发送通知，告知 UI 同步
        NotificationCenter.postCurrentFileDidChange(path: path)

        return """
        ✅ Successfully set current file

        **File Name**: \(fileName)

        **File Path**: \(path)

        The file has been saved and is ready to use.
        """
    }
}
