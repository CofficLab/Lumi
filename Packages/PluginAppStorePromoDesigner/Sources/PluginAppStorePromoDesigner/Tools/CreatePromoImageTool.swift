import AgentToolKit
import AppStorePromoKit
import Foundation

/// 在任务下，从有效的响应式 HTML 文档创建一张图片。
public struct CreatePromoImageTool: SuperAgentTool {
    public let name = "app_store_promo_create_image"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Create one image under a promotional task from a valid responsive HTML document."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["imageId"] = ["type": "string", "description": "Lowercase kebab-case image slug."]
        properties["title"] = ["type": "string"]
        properties["html"] = ["type": "string", "description": "Optional complete HTML document. Never pass a fragment."]
        return ["type": "object", "properties": properties, "required": ["taskId", "imageId", "title"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PromoToolSupport.localized(PromoToolSupport.language, en: "Create promo HTML image", zh: "创建促销图 HTML 图片")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let scope = try await PromoToolSupport.resolveScope(arguments)
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let imageID = try PromoToolSupport.required("imageId", arguments)
        _ = try PromoToolSupport.store.createImage(
            storagePath: try await PromoToolSupport.storagePath(for: scope),
            taskSlug: taskID,
            imageSlug: imageID,
            title: try PromoToolSupport.required("title", arguments),
            html: PromoToolSupport.string(arguments, "html")
        )
        await PromoToolSupport.notify(scope: scope, taskID: taskID, imageID: imageID)
        return "Created promotional HTML image (scope=\(scope.rawValue)). imageId=\(imageID)\nEdit it with app_store_promo_replace_html or app_store_promo_patch_html, then call app_store_promo_preview_image."
    }
}
