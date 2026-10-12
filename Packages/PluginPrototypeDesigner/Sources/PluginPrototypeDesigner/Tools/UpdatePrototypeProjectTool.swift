import Foundation
import KitAgentTool
import KitPrototype

/// 重命名原型项目，或切换它的画板设备与视觉风格。
public struct UpdatePrototypeProjectTool: SuperAgentTool {
    public let name = "prototype_update_project"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Rename a prototype project and/or change its device canvas. Use this when the target device changes; existing screen HTML keeps its own layout, so re-check each screen with prototype_preview_screen afterwards."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = PrototypeToolSupport.baseProperties()
        properties["title"] = ["type": "string", "description": "Optional new project title."]
        properties.merge(PrototypeToolSupport.deviceProperties) { current, _ in current }
        return ["type": "object", "properties": properties, "required": ["projectId"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PrototypeToolSupport.localized(PrototypeToolSupport.language, en: "Update prototype", zh: "更新原型项目")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let storagePath = try await PrototypeToolSupport.storagePath()
        let projectID = try PrototypeToolSupport.required("projectId", arguments)
        var project = try PrototypeToolSupport.store.readProject(
            storagePath: storagePath,
            projectSlug: projectID
        )

        if let title = PrototypeToolSupport.string(arguments, "title"), !title.isEmpty {
            project = try PrototypeToolSupport.store.renameProject(
                storagePath: storagePath,
                projectSlug: projectID,
                title: title
            )
        }
        if PrototypeToolSupport.string(arguments, "deviceKind") != nil {
            project = try PrototypeToolSupport.store.updateDevice(
                storagePath: storagePath,
                projectSlug: projectID,
                device: try PrototypeToolSupport.device(from: arguments)
            )
        }

        await PrototypeToolSupport.notify(projectID: projectID)
        return "Updated prototype project.\n\(PrototypeToolSupport.projectSummary(project))"
    }
}
