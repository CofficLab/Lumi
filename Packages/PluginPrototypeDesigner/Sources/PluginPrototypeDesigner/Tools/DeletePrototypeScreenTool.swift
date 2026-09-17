import Foundation
import KitAgentTool
import KitPrototype

/// 删除原型项目中的一屏。
public struct DeletePrototypeScreenTool: SuperAgentTool {
    public let name = "prototype_delete_screen"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Delete one screen from a prototype project. Other screens that link to it keep a dangling data-prototype-link; call prototype_lint afterwards to find them."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": PrototypeToolSupport.baseProperties(includeScreen: true), "required": ["projectId", "screenId"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PrototypeToolSupport.localized(PrototypeToolSupport.language, en: "Delete prototype screen", zh: "删除原型屏幕")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .high
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let projectID = try PrototypeToolSupport.required("projectId", arguments)
        let screenID = try PrototypeToolSupport.required("screenId", arguments)
        try PrototypeToolSupport.store.deleteScreen(
            storagePath: try await PrototypeToolSupport.storagePath(),
            projectSlug: projectID,
            screenSlug: screenID
        )
        await PrototypeToolSupport.notify(projectID: projectID)
        let project = try PrototypeToolSupport.store.readProject(
            storagePath: try await PrototypeToolSupport.storagePath(),
            projectSlug: projectID
        )
        return "Deleted screen \(screenID).\n\(PrototypeToolSupport.projectSummary(project))"
    }
}
