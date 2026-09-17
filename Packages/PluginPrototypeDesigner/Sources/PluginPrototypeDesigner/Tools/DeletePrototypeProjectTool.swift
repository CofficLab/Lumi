import Foundation
import KitAgentTool
import KitPrototype

/// 删除一个原型项目及其全部屏幕。
public struct DeletePrototypeProjectTool: SuperAgentTool {
    public let name = "prototype_delete_project"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Delete a prototype project and all of its screens. Destructive and not undoable; confirm with the user before calling it."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": PrototypeToolSupport.baseProperties(), "required": ["projectId"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PrototypeToolSupport.localized(PrototypeToolSupport.language, en: "Delete prototype", zh: "删除原型项目")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let projectID = try PrototypeToolSupport.required("projectId", arguments)
        let storagePath = try await PrototypeToolSupport.storagePath()
        let project = try PrototypeToolSupport.store.readProject(storagePath: storagePath, projectSlug: projectID)
        try PrototypeToolSupport.store.deleteProject(storagePath: storagePath, projectSlug: projectID)
        await PrototypeToolSupport.notify()
        return "Deleted prototype project \(projectID) (title=\(project.title), screens=\(project.screens.count))."
    }
}
