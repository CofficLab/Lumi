import Foundation
import MagicKit

/// 设置当前文件工具
struct SetCurrentFileTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📄"
    nonisolated static let verbose: Bool = true
    let name = "set_current_file"
    let description = "Set the current selected file. Requires a file path."

    var inputSchema: [String: Any] {
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

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let path = arguments["path"]?.value as? String else {
            return "❌ Error: Missing required parameter 'path'"
        }

        if Self.verbose {
            BreadcrumbPlugin.logger.info("\(Self.t)Setting current file: \(path)")
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

        let fileName = URL(fileURLWithPath: path).lastPathComponent
        
        // 使用 store 设置当前文件
        let store = RecentProjectsStore()
        store.setCurrentFile(path: path)
        
        // 发送通知，告知 UI 同步到 ProjectVM
        NotificationCenter.postCurrentFileDidChange(path: path)

        return """
        ✅ Successfully set current file
        
        **File Name**: \(fileName)
        
        **File Path**: \(path)
        
        The file has been saved and is ready to use.
        """
    }
}