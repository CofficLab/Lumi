import Foundation
import KitAgentTool
import KitPrototype

/// 在原型项目下新增一屏。
///
/// 不传 `html` 时按项目风格生成起始模板；传入时必须是完整 HTML 文档。
public struct AddPrototypeScreenTool: SuperAgentTool {
    public let name = "prototype_add_screen"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Add one screen to a prototype project. Omit 'html' to start from the project's style template, or pass a complete HTML document. The first screen added becomes the start screen."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = PrototypeToolSupport.baseProperties(includeScreen: true)
        properties["screenId"] = ["type": "string", "description": "Lowercase kebab-case screen slug, e.g. 01-home. This slug is the navigation target used by data-prototype-link."]
        properties["title"] = ["type": "string", "description": "Human-readable screen title."]
        properties["html"] = ["type": "string", "description": "Optional complete HTML document. Never pass a fragment."]
        return ["type": "object", "properties": properties, "required": ["projectId", "screenId", "title"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PrototypeToolSupport.localized(PrototypeToolSupport.language, en: "Add prototype screen", zh: "新增原型屏幕")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let projectID = try PrototypeToolSupport.required("projectId", arguments)
        let screenID = try PrototypeToolSupport.required("screenId", arguments)
        let screen = try PrototypeToolSupport.store.addScreen(
            storagePath: try await PrototypeToolSupport.storagePath(),
            projectSlug: projectID,
            screenSlug: screenID,
            title: try PrototypeToolSupport.required("title", arguments),
            html: PrototypeToolSupport.string(arguments, "html")
        )
        await PrototypeToolSupport.notify(projectID: projectID, screenID: screenID)
        return "Added screen.\n\(PrototypeToolSupport.screenSummary(screen.screen))\n"
            + "Edit it with prototype_replace_html or prototype_patch_html, then call prototype_preview_screen to inspect the render."
    }
}
