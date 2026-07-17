import Foundation
import LumiCoreKit
import SuperLogKit

struct ListProjectsTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📋"
    public nonisolated static let verbose: Bool = true

    static let info = LumiAgentToolInfo(
        id: "list_projects",
        displayName: LumiPluginLocalization.string("List Projects", bundle: .module),
        description: LumiPluginLocalization.string("List saved projects with project names, paths, and last used times.", bundle: .module)
    )

    init() {}

    private let maxLimit = 500

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum number of projects to return. Defaults to 5, maximum 500.")
                ])
            ])
        ])
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "列出项目"
    }

    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .safe
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let limit = min(arguments["limit"]?.intValue ?? 5, maxLimit)

        if Self.verbose {
            if ProjectsPlugin.verbose {
                ProjectsPlugin.logger.info("\(Self.t)执行 list_projects，limit=\(limit)")
            }
        }

        return await MainActor.run {
            guard let viewModel = ProjectsPlugin.viewModel else {
                if Self.verbose {
                    if ProjectsPlugin.verbose {
                        ProjectsPlugin.logger.error("\(Self.t)❌ list_projects 失败：Projects view model is not available")
                    }
                }
                return "Error: Projects view model is not available."
            }

            let projects = Array(viewModel.projects.prefix(limit))

            if Self.verbose {
                if ProjectsPlugin.verbose {
                    ProjectsPlugin.logger.info("\(Self.t)找到 \(projects.count) 个项目（limit=\(limit)，总计=\(viewModel.projects.count)）")
                }
            }

            guard !projects.isEmpty else {
                if Self.verbose {
                    if ProjectsPlugin.verbose {
                        ProjectsPlugin.logger.warning("\(Self.t)⚠️ list_projects 返回空：没有项目")
                    }
                }
                return "No projects found."
            }

            var output = "## Projects\n\n"
            for (index, project) in projects.enumerated() {
                output += "\(index + 1). **\(project.name)**"
                if viewModel.currentProject?.path == project.path {
                    output += " (current)"
                }
                output += "\n"
                output += "   Path: `\(project.path)`\n"
                output += "   Last used: \(Self.formatDate(project.lastUsed))\n\n"
            }

            if Self.verbose {
                if ProjectsPlugin.verbose {
                    ProjectsPlugin.logger.info("\(Self.t)✅ list_projects 成功，返回 \(projects.count) 个项目")
                }
            }

            return output
        }
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private extension LumiJSONValue {
    var intValue: Int? {
        switch self {
        case .int(let value):
            value
        case .double(let value):
            Int(value)
        case .string(let value):
            Int(value)
        default:
            nil
        }
    }
}
