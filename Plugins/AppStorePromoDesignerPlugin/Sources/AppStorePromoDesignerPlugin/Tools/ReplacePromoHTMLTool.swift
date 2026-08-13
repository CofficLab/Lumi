import AppStorePromoKit
import Foundation
import KernelLumi

public struct ReplacePromoHTMLTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_replace_html",
        displayName: "Replace promo HTML",
        description: "Validate and atomically replace a promotional image with a complete deterministic HTML document."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["html"] = ["type": "string", "description": "Complete HTML document including doctype, head, viewport, style, and body."]
        return ["type": "object", "properties": .object(properties), "required": ["taskId", "imageId", "html"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel { .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let scope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let imageID = try PromoToolSupport.required("imageId", arguments)
        let image = try PromoToolSupport.store.replaceHTML(
            try PromoToolSupport.required("html", arguments),
            storagePath: try await PromoToolSupport.storagePath(for: scope),
            taskSlug: taskID,
            imageSlug: imageID,
            localeIdentifier: arguments.string("localeIdentifier")
        )
        await PromoToolSupport.notify(scope: scope, taskID: taskID, imageID: imageID)
        return "Promotional HTML updated and validated (scope=\(scope.rawValue), locale=\(image.localeIdentifier)). bytes=\(image.html.utf8.count)\nCall app_store_promo_preview_image to inspect the rendered result."
    }
}
