import Foundation
import MagicKit

/// 设置当前项目工具
struct SetCurrentProjectTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose: Bool = true
    let name = "set_current_project"
    let description = "Set the current selected project. Requires a project path."

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "Absolute path to the project root directory",
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
            BreadcrumbPlugin.logger.info("\(Self.t)Setting current project: \(path)")
        }

        // 验证路径是否存在且为目录
        let fm = FileManager.default
        var isDirectory: ObjCBool = false

        guard fm.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return "❌ Error: Path does not exist: \(path)"
        }

        guard isDirectory.boolValue else {
            return "❌ Error: Path is not a directory: \(path)"
        }

        let projectName = URL(fileURLWithPath: path).lastPathComponent
        
        // 使用 store 设置当前项目（会自动添加到最近列表）
        let store = RecentProjectsStore()
        store.setCurrentProject(name: projectName, path: path)
        
        // 发送通知，告知 RootView 同步到 ProjectVM
        NotificationCenter.postCurrentProjectDidChange(name: projectName, path: path)

        return """
        ✅ Successfully set current project
        
        **Project Name**: \(projectName)
        
        **Project Path**: \(path)
        
        The project has been saved and is ready to use.
        """
    }
}