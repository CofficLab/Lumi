import Foundation
import MagicKit

/// 设置当前项目工具
struct SetCurrentProjectTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose: Bool = true
    let name = "set_current_project"
    let description = "设置当前选中的项目。需要提供项目路径。"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "项目根目录的绝对路径",
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
            return "❌ 错误：需要提供项目路径参数"
        }

        if Self.verbose {
            BreadcrumbPlugin.logger.info("\(Self.t)设置当前项目：\(path)")
        }

        // 验证路径是否存在且为目录
        let fm = FileManager.default
        var isDirectory: ObjCBool = false

        guard fm.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return "❌ 错误：路径不存在：\(path)"
        }

        guard isDirectory.boolValue else {
            return "❌ 错误：路径不是目录：\(path)"
        }

        let projectName = URL(fileURLWithPath: path).lastPathComponent
        
        // 使用 store 设置当前项目（会自动添加到最近列表）
        let store = RecentProjectsStore()
        store.setCurrentProject(name: projectName, path: path)
        
        // 发送通知，告知 RootView 同步到 ProjectVM
        NotificationCenter.postCurrentProjectDidChange(name: projectName, path: path)

        return """
        ✅ 已成功设置当前项目
        
        **项目名称**: \(projectName)
        
        **项目路径**: \(path)
        
        项目已保存，可以开始使用项目相关的功能。
        """
    }
}