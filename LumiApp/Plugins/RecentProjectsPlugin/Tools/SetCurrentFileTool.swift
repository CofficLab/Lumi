import Foundation
import MagicKit

/// 设置当前文件工具
struct SetCurrentFileTool: AgentTool, SuperLog {
    nonisolated static let emoji = "📄"
    nonisolated static let verbose = true

    let name = "set_current_file"
    let description = "设置当前选中的文件。需要提供文件路径。"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "文件的绝对路径",
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
            return "❌ 错误：需要提供文件路径参数"
        }

        if Self.verbose {
            RecentProjectsPlugin.logger.info("\(Self.t)设置当前文件：\(path)")
        }

        // 验证路径是否存在且为文件
        let fm = FileManager.default
        var isDirectory: ObjCBool = false

        guard fm.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return "❌ 错误：路径不存在：\(path)"
        }

        guard !isDirectory.boolValue else {
            return "❌ 错误：路径是目录而非文件：\(path)"
        }

        let fileName = URL(fileURLWithPath: path).lastPathComponent
        
        // 使用 store 设置当前文件
        let store = RecentProjectsStore()
        store.setCurrentFile(path: path)
        
        // 发送通知，告知 UI 同步到 ProjectVM
        NotificationCenter.postCurrentFileDidChange(path: path)

        return """
        ✅ 已成功设置当前文件
        
        **文件名称**: \(fileName)
        
        **文件路径**: \(path)
        
        文件已保存，可以开始使用文件相关的功能。
        """
    }
}