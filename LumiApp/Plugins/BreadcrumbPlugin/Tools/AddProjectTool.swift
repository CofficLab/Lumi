import Foundation
import MagicKit

/// 添加项目到最近列表工具
struct AddProjectTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose: Bool = true
    let name = "add_recent_project"
    let description = "Add the specified project to the recent projects list. Updates the projectVM's recent projects after adding."

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
            BreadcrumbPlugin.logger.info("\(Self.t)Adding project to recent list: \(path)")
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

        // 1. 使用 store 添加项目到最近列表
        let store = RecentProjectsStore()
        store.addProject(name: projectName, path: path)

        // 2. 发送通知，RecentProjectsPersistenceOverlay 会自动更新 projectVM
        NotificationCenter.postCurrentProjectDidChange(name: projectName, path: path)

        // 3. 加载更新后的最近项目列表
        let recentProjects = store.loadProjects()

        // 构建返回消息
        var output = "✅ Successfully added project to recent list\n\n"
        output += "**Project Name**: \(projectName)\n\n"
        output += "**Project Path**: \(path)\n\n"

        // 显示更新后的最近项目列表
        output += "## Recent Projects (\(recentProjects.count) total)\n\n"
        for (index, project) in recentProjects.prefix(5).enumerated() {
            output += "\(index + 1). **\(project.name)**\n"
            output += "   Path: `\(project.path)`\n\n"
        }

        return output
    }
}