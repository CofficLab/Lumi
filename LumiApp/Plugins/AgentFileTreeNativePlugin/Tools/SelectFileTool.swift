import Foundation
import MagicKit

/// 选中文件工具
struct SelectFileTool: AgentTool, SuperLog {
    nonisolated static let emoji = "📄"
    nonisolated static let verbose = true

    let name = "select_file"
    let description = "选中指定文件或目录，让应用知道用户当前关注的对象。"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "要选中的文件或目录的绝对路径",
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
            AgentNativeFileTreePlugin.logger.info("\(Self.t)选中文件：\(path)")
        }

        // 验证路径是否存在
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else {
            return "❌ 错误：路径不存在：\(path)"
        }

        let url = URL(fileURLWithPath: path)
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

        // 发送通知，FileTreeSyncOverlay 会更新 projectVM
        NotificationCenter.postSyncSelectedFile(path: path)

        // 返回结果
        let fileName = url.lastPathComponent
        if isDirectory {
            return """
            ✅ 已选中目录

            **目录名称**: \(fileName)

            **目录路径**: \(path)
            """
        } else {
            return """
            ✅ 已选中文件

            **文件名称**: \(fileName)

            **文件路径**: \(path)
            """
        }
    }
}