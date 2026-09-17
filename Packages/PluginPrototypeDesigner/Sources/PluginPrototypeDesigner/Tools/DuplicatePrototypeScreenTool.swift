import Foundation
import KitAgentTool
import KitPrototype

/// 复制一屏为新的屏幕，作为变体的起点。
public struct DuplicatePrototypeScreenTool: SuperAgentTool {
    public let name = "prototype_duplicate_screen"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Duplicate one screen into a new screen. Useful for building a variant (e.g. an empty state or a second tab) without rewriting the layout from scratch."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = PrototypeToolSupport.baseProperties(includeScreen: true)
        properties["newScreenId"] = ["type": "string", "description": "Slug for the new screen."]
        properties["title"] = ["type": "string", "description": "Optional title. Defaults to the source screen's title."]
        return [
            "type": "object",
            "properties": properties,
            "required": ["projectId", "screenId", "newScreenId"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PrototypeToolSupport.localized(PrototypeToolSupport.language, en: "Duplicate prototype screen", zh: "复制原型屏幕")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let projectID = try PrototypeToolSupport.required("projectId", arguments)
        let newScreenID = try PrototypeToolSupport.required("newScreenId", arguments)
        let screen = try PrototypeToolSupport.store.duplicateScreen(
            storagePath: try await PrototypeToolSupport.storagePath(),
            projectSlug: projectID,
            screenSlug: try PrototypeToolSupport.required("screenId", arguments),
            newScreenSlug: newScreenID,
            title: PrototypeToolSupport.string(arguments, "title")
        )
        await PrototypeToolSupport.notify(projectID: projectID, screenID: newScreenID)
        return "Duplicated screen.\n\(PrototypeToolSupport.screenSummary(screen.screen))"
    }
}
