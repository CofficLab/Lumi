import AppStorePromoKit
import Foundation
import KernelLumi

public struct CreatePromoImageTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_create_image",
        displayName: "Create promo HTML image",
        description: "Create one image under a promotional task from a valid responsive HTML document."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["imageId"] = ["type": "string", "description": "Lowercase kebab-case image slug."]
        properties["title"] = ["type": "string"]
        properties["html"] = ["type": "string", "description": "Optional complete HTML document. Never pass a fragment."]
        return ["type": "object", "properties": .object(properties), "required": ["taskId", "imageId", "title"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel { .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let scope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let imageID = try PromoToolSupport.required("imageId", arguments)
        _ = try PromoToolSupport.store.createImage(
            storagePath: try await PromoToolSupport.storagePath(for: scope),
            taskSlug: taskID, imageSlug: imageID,
            title: try PromoToolSupport.required("title", arguments),
            html: arguments.string("html")
        )
        await PromoToolSupport.notify(scope: scope, taskID: taskID, imageID: imageID)
        return "Created promotional HTML image (scope=\(scope.rawValue)). imageId=\(imageID)\nEdit it with app_store_promo_replace_html or app_store_promo_patch_html, then call app_store_promo_preview_image."
    }
}