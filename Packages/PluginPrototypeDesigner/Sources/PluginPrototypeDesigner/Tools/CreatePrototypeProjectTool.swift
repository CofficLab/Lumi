import Foundation
import KitAgentTool
import KitPrototype

/// 创建一个原型项目，并在生成 HTML 之前确定设备与视觉风格。
public struct CreatePrototypeProjectTool: SuperAgentTool {
    public let name = "prototype_create_project"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Create one prototype project before generating its screen HTML. Pick the device canvas and visual style first; every later screen inherits them."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = PrototypeToolSupport.baseProperties()
        properties["slug"] = ["type": "string", "description": "Lowercase kebab-case project slug."]
        properties["title"] = ["type": "string", "description": "Human-readable project title."]
        properties["style"] = ["type": "string", "enum": PrototypeStyle.allCases.map(\.rawValue)]
        properties.merge(PrototypeToolSupport.deviceProperties) { current, _ in current }
        return [
            "type": "object",
            "properties": properties,
            "required": ["slug", "title", "style", "deviceKind"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PrototypeToolSupport.localized(PrototypeToolSupport.language, en: "Create prototype", zh: "创建原型项目")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let styleRaw = try PrototypeToolSupport.required("style", arguments)
        guard let style = PrototypeStyle(rawValue: styleRaw) else {
            throw PrototypeToolSupport.ToolArgumentError.invalid("style")
        }
        let device = try PrototypeToolSupport.device(from: arguments)
        let project = try PrototypeToolSupport.store.createProject(
            storagePath: try await PrototypeToolSupport.storagePath(),
            slug: try PrototypeToolSupport.required("slug", arguments),
            title: try PrototypeToolSupport.required("title", arguments),
            style: style,
            device: device
        )
        await PrototypeToolSupport.notify(projectID: project.id)
        return "Created prototype project.\n\(PrototypeToolSupport.projectSummary(project))\nNext: add screens with prototype_add_screen."
    }
}
