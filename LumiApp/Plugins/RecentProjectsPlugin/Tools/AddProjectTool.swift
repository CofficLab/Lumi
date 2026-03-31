import Foundation
import MagicKit

/// 添加项目到最近列表工具
struct AddProjectTool: AgentTool, SuperLog {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose = true

    let name = "add_recent_project"
    let description = "将指定项目添加到最近项目列表。添加后会更新 projectVM 中的最近项目。"

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
            RecentProjectsPlugin.logger.info("\(Self.t)添加项目到最近列表：\(path)")
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

        // 1. 使用 store 添加项目到最近列表
        let store = RecentProjectsStore()
        store.addProject(name: projectName, path: path)

        // 2. 发送通知，RecentProjectsPersistenceOverlay 会自动更新 projectVM
        NotificationCenter.postCurrentProjectDidChange(name: projectName, path: path)

        // 3. 加载更新后的最近项目列表
        let recentProjects = store.loadProjects()

        // 构建返回消息
        var output = "✅ 已成功添加项目到最近列表\n\n"
        output += "**项目名称**: \(projectName)\n\n"
        output += "**项目路径**: \(path)\n\n"

        // 显示更新后的最近项目列表
        output += "## 最近项目列表（\(recentProjects.count) 个）\n\n"
        for (index, project) in recentProjects.prefix(5).enumerated() {
            output += "\(index + 1). **\(project.name)**\n"
            output += "   Path: `\(project.path)`\n\n"
        }

        return output
    }
}