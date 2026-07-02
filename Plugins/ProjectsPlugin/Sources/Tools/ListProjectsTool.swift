import Foundation
import LumiCoreKit

struct ListProjectsTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "list_projects",
        displayName: LumiPluginLocalization.string("List Projects", bundle: .module),
        description: LumiPluginLocalization.string("List saved projects with project names, paths, and last used times.", bundle: .module)
    )

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

        return await MainActor.run {
            let store = ProjectsStore.shared
            let projects = Array(store.projects.prefix(limit))

            guard !projects.isEmpty else {
                return "No projects found."
            }

            var output = "## Projects\n\n"
            for (index, project) in projects.enumerated() {
                output += "\(index + 1). **\(project.name)**"
                if store.currentProject?.path == project.path {
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
