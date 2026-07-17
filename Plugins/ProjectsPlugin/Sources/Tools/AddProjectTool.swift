import Foundation
import LumiCoreKit
import SuperLogKit

struct AddProjectTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "➕"
    public nonisolated static let verbose: Bool = true

    static let info = LumiAgentToolInfo(
        id: "add_project",
        displayName: LumiPluginLocalization.string("Add Project", bundle: .module),
        description: LumiPluginLocalization.string("Add an existing local directory to the projects list without switching the current project.", bundle: .module)
    )

    init() {}

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "path": .object([
                    "type": .string("string"),
                    "description": .string("Absolute path to the project root directory.")
                ])
            ]),
            "required": .array([.string("path")])
        ])
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        guard let path = arguments["path"]?.stringValue else {
            return "添加项目"
        }

        return "添加 \(URL(fileURLWithPath: path).lastPathComponent)"
    }

    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        if Self.verbose {
            if ProjectsPlugin.verbose {
                ProjectsPlugin.logger.info("\(Self.t)执行 add_project，参数 path=\(arguments["path"]?.stringValue ?? "<nil>")")
            }
        }

        guard let path = arguments["path"]?.stringValue else {
            if Self.verbose {
                if ProjectsPlugin.verbose {
                    ProjectsPlugin.logger.warning("\(Self.t)⚠️ add_project 缺少必需参数 path")
                }
            }
            return "Error: Missing required parameter `path`."
        }

        return await MainActor.run {
            guard let viewModel = ProjectsPlugin.viewModel else {
                if Self.verbose {
                    if ProjectsPlugin.verbose {
                        ProjectsPlugin.logger.error("\(Self.t)❌ add_project 失败：Projects view model is not available")
                    }
                }
                return "Error: Projects view model is not available."
            }

            do {
                if Self.verbose {
                    if ProjectsPlugin.verbose {
                        ProjectsPlugin.logger.info("\(Self.t)尝试添加项目：\(path)")
                    }
                }

                let project = try viewModel.add(path: path, select: false)

                if Self.verbose {
                    if ProjectsPlugin.verbose {
                        ProjectsPlugin.logger.info("\(Self.t)✅ 项目添加成功：\(project.name) (\(project.path))")
                    }
                }

                return Self.successMessage(project: project, projects: viewModel.projects)
            } catch {
                if Self.verbose {
                    if ProjectsPlugin.verbose {
                        ProjectsPlugin.logger.error("\(Self.t)❌ add_project 失败：\(error.localizedDescription)")
                    }
                }
                return "Error: \(error.localizedDescription)"
            }
        }
    }

    private static func successMessage(project: ProjectEntry, projects: [ProjectEntry]) -> String {
        var output = """
        Successfully added project.

        **Project Name**: \(project.name)

        **Project Path**: \(project.path)

        ## Projects (\(projects.count) total)

        """

        for (index, project) in projects.prefix(5).enumerated() {
            output += "\(index + 1). **\(project.name)**\n"
            output += "   Path: `\(project.path)`\n\n"
        }

        return output
    }
}
