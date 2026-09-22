import Foundation
import KitAgentTool
import KitPrototype

/// 重排原型项目中的屏幕顺序。
public struct ReorderPrototypeScreensTool: SuperAgentTool {
    public let name = "prototype_reorder_screens"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Reorder the screens of a prototype project. The screen order is the reading order of the flow, so keep it in narrative sequence."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = PrototypeToolSupport.baseProperties()
        properties["screenIds"] = [
            "type": "array",
            "items": ["type": "string"],
            "description": "Every screen slug in the project, exactly once, in the desired order.",
        ]
        return ["type": "object", "properties": properties, "required": ["projectId", "screenIds"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PrototypeToolSupport.localized(PrototypeToolSupport.language, en: "Reorder prototype screens", zh: "重排原型屏幕")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let projectID = try PrototypeToolSupport.required("projectId", arguments)
        guard let screenIDs = PrototypeToolSupport.stringArray(arguments, "screenIds") else {
            throw PrototypeToolSupport.ToolArgumentError.invalid("screenIds")
        }
        let project = try PrototypeToolSupport.store.reorderScreens(
            storagePath: try await PrototypeToolSupport.storagePath(),
            projectSlug: projectID,
            orderedScreenIDs: screenIDs
        )
        await PrototypeToolSupport.notify(projectID: projectID)
        return "Reordered screens.\n\(PrototypeToolSupport.projectSummary(project))"
    }
}
