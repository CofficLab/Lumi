import Foundation
import KitAgentTool
import KitPrototype

/// 用完整 HTML 文档原子替换一屏。
public struct ReplacePrototypeHTMLTool: SuperAgentTool {
    public let name = "prototype_replace_html"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Validate and atomically replace one screen with a complete deterministic HTML document. Use for large rewrites; use prototype_patch_html for small edits."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = PrototypeToolSupport.baseProperties(includeScreen: true)
        properties["html"] = [
            "type": "string",
            "description": "Complete HTML document including doctype, head, viewport, style, and body. Never pass a fragment.",
        ]
        return ["type": "object", "properties": properties, "required": ["projectId", "screenId", "html"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PrototypeToolSupport.localized(PrototypeToolSupport.language, en: "Replace screen HTML", zh: "替换屏幕 HTML")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let projectID = try PrototypeToolSupport.required("projectId", arguments)
        let screenID = try PrototypeToolSupport.required("screenId", arguments)
        let resolved = try PrototypeToolSupport.store.replaceScreenHTML(
            try PrototypeToolSupport.required("html", arguments),
            storagePath: try await PrototypeToolSupport.storagePath(),
            projectSlug: projectID,
            screenSlug: screenID
        )
        await PrototypeToolSupport.notify(projectID: projectID, screenID: screenID)
        return "Screen HTML replaced and validated. bytes=\(resolved.html.utf8.count)\n"
            + "\(PrototypeToolSupport.screenSummary(resolved.screen))\n"
            + "Call prototype_preview_screen to inspect the rendered result."
    }
}
