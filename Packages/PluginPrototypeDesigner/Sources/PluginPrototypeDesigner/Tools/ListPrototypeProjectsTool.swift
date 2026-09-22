import Foundation
import KitAgentTool
import KitPrototype

/// 列出当前项目内由插件管理的原型项目。
public struct ListPrototypeProjectsTool: SuperAgentTool {
    public let name = "prototype_list_projects"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "List plugin-managed prototype projects and their screens in the current project."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": [:]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PrototypeToolSupport.localized(PrototypeToolSupport.language, en: "List prototypes", zh: "列出原型项目")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let projects = try PrototypeToolSupport.store.listProjects(
            storagePath: await PrototypeToolSupport.storagePath()
        )
        guard !projects.isEmpty else {
            return "No prototype projects found. Call prototype_create_project to start one."
        }
        return projects.map(PrototypeToolSupport.projectSummary).joined(separator: "\n---\n")
    }
}
