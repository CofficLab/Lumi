import KitAgentTool
import Foundation

/// List Projects Tool
public struct ListProjectsTool: SuperAgentTool {
    public let name = "list_projects"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "List saved projects with project names, paths, and last used times."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "limit": [
                    "type": "integer",
                    "description": "Maximum number of projects to return (default: 5, min: 1, max: 500)",
                ],
            ],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "List projects"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .safe
    }

    private static let defaultLimit = 5
    private static let maxLimit = 500

    /// 解析 `limit`：缺省取默认值，超出上限安全截断；
    /// 显式传入无法解析或小于 1 的值返回 nil，由调用方转为参数错误。
    ///
    /// `prefix(_:)` 对负数会触发 precondition，因此必须先在这里收住。
    static func resolvedLimit(arguments: [String: ToolArgument]) -> Int? {
        guard arguments["limit"]?.value != nil else { return defaultLimit }
        guard let requested = ProjectToolSupport.int(arguments, "limit"), requested >= 1 else {
            return nil
        }
        return min(requested, maxLimit)
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let limit = Self.resolvedLimit(arguments: arguments) else {
            throw ToolExecutionError.executionFailed(
                toolName: name,
                reason: "'limit' must be an integer between 1 and \(Self.maxLimit)."
            )
        }

        guard let viewModel = await MainActor.run(body: { ProjectsRuntime.viewModel }) else {
            throw ToolExecutionError.executionFailed(toolName: name, reason: "Projects view model is not available.")
        }

        return await MainActor.run {
            let projects = Array(viewModel.projects.prefix(limit))

            guard !projects.isEmpty else {
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
