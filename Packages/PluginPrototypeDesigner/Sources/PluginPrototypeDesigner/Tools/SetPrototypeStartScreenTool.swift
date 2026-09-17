import Foundation
import KitAgentTool
import KitPrototype

/// 指定原型项目的起始屏（演示时进入的第一屏）。
public struct SetPrototypeStartScreenTool: SuperAgentTool {
    public let name = "prototype_set_start_screen"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Set which screen the prototype starts on. Defaults to the first screen when unset."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": PrototypeToolSupport.baseProperties(includeScreen: true), "required": ["projectId", "screenId"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PrototypeToolSupport.localized(PrototypeToolSupport.language, en: "Set start screen", zh: "设置起始屏")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let projectID = try PrototypeToolSupport.required("projectId", arguments)
        let screenID = try PrototypeToolSupport.required("screenId", arguments)
        let project = try PrototypeToolSupport.store.setStartScreen(
            storagePath: try await PrototypeToolSupport.storagePath(),
            projectSlug: projectID,
            screenSlug: screenID
        )
        await PrototypeToolSupport.notify(projectID: projectID, screenID: screenID)
        return "Start screen set to \(screenID).\n\(PrototypeToolSupport.projectSummary(project))"
    }
}
