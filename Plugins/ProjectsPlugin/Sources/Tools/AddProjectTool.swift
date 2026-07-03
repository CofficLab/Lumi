import Foundation
import LumiCoreKit

struct AddProjectTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "add_project",
        displayName: LumiPluginLocalization.string("Add Project", bundle: .module),
        description: LumiPluginLocalization.string("Add an existing local directory to the projects list without switching the current project.", bundle: .module)
    )

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
        guard let path = arguments["path"]?.stringValue else {
            return "Error: Missing required parameter `path`."
        }

        return await MainActor.run {
            do {
                let store = ProjectsStore.shared
                let project = try store.add(path: path, select: false)
                return Self.successMessage(project: project, projects: store.projects)
            } catch {
                return "Error: \(error.localizedDescription)"
            }
        }
    }

    private static func successMessage(project: LumiProject, projects: [LumiProject]) -> String {
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
