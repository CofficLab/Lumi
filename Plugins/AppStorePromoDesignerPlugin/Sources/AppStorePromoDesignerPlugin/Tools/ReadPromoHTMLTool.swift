import AppStorePromoKit
import Foundation
import LumiKernel

public struct ReadPromoHTMLTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_read_html",
        displayName: "Read promo HTML",
        description: "Read the full index.html for a promotional image before editing it."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        ["type": "object", "properties": .object(PromoToolSupport.baseProperties(includeImage: true)), "required": ["taskId", "imageId"]]
    }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let scope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
        let image = try PromoToolSupport.store.readImage(
            storagePath: try await PromoToolSupport.storagePath(for: scope),
            taskSlug: try PromoToolSupport.required("taskId", arguments),
            imageSlug: try PromoToolSupport.required("imageId", arguments)
        )
        return "--- index.html ---\n\(image.html)"
    }
}