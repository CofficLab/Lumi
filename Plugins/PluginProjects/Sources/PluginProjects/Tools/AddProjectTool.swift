import Foundation
import SuperLogKit
import AgentToolKit
import LumiCoreKit

/// 添加项目到列表工具
public struct AddProjectTool: SuperAgentTool, SuperLog {
    public nonisolated static let emoji = "📁"
    public nonisolated static let verbose: Bool = true
    public let name = "add_project"
    public func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "将指定项目添加到项目列表。仅更新列表，不会切换当前项目。"
        case .english:
            return "Add the specified project to the projects list. Only updates the list without switching the current project."
        }
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
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

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {        "添加项目"    }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    // MARK: - Dependencies

    private weak var recentProjectsVM: AppProjectsVM?

    public init(recentProjectsVM: AppProjectsVM? = nil) {
        self.recentProjectsVM = recentProjectsVM
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        guard let path = arguments["path"]?.value as? String else {
            return "❌ Error: Missing required parameter 'path'"
        }

        if Self.verbose {
            if ProjectsPlugin.verbose {
                            ProjectsPlugin.logger.info("\(Self.t)Adding project to list: \(path)")
            }
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
        let newProject = Project(name: projectName, path: path, lastUsed: Date())

        // 1. 使用 store 持久化项目到磁盘
        let store = ProjectsStore()
        store.addProject(name: projectName, path: path)

        // 2. 同步更新内存中的 AppProjectsVM，使 UI 立即刷新
        await MainActor.run { [weak recentProjectsVM] in
            recentProjectsVM?.addProject(newProject)
        }

        // 3. 加载更新后的项目列表
        let projects = store.loadProjects()

        // 构建返回消息
        var output = "✅ Successfully added project to list\n\n"
        output += "**Project Name**: \(projectName)\n\n"
        output += "**Project Path**: \(path)\n\n"

        // 显示更新后的项目列表
        output += "## Projects (\(projects.count) total)\n\n"
        for (index, project) in projects.prefix(5).enumerated() {
            output += "\(index + 1). **\(project.name)**\n"
            output += "   Path: `\(project.path)`\n\n"
        }

        return output
    }
}
