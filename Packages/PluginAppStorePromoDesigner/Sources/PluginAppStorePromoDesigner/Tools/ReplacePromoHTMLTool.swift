import KitAgentTool
import KitAppStorePromo
import Foundation

/// 校验并用完整的确定性 HTML 文档原子替换促销图。
public struct ReplacePromoHTMLTool: SuperAgentTool {
    public let name = "app_store_promo_replace_html"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Validate and atomically replace a promotional image with a complete deterministic HTML document."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["html"] = ["type": "string", "description": "Complete HTML document including doctype, head, viewport, style, and body."]
        return ["type": "object", "properties": properties, "required": ["taskId", "imageId", "html"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PromoToolSupport.localized(PromoToolSupport.language, en: "Replace promo HTML", zh: "替换促销图 HTML")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let scope = try await PromoToolSupport.resolveScope(arguments)
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let imageID = try PromoToolSupport.required("imageId", arguments)
        let image = try PromoToolSupport.store.replaceHTML(
            try PromoToolSupport.required("html", arguments),
            storagePath: try await PromoToolSupport.storagePath(for: scope),
            taskSlug: taskID,
            imageSlug: imageID,
            localeIdentifier: PromoToolSupport.string(arguments, "localeIdentifier")
        )
        await PromoToolSupport.notify(scope: scope, taskID: taskID, imageID: imageID)
        return "Promotional HTML updated and validated (scope=\(scope.rawValue), locale=\(image.localeIdentifier)). bytes=\(image.html.utf8.count)\nCall app_store_promo_preview_image to inspect the rendered result."
    }
}
