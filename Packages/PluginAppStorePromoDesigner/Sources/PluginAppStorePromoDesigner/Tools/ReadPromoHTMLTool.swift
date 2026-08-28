import KitAgentTool
import KitAppStorePromo
import Foundation

/// 在编辑前读取促销图的完整 index.html。
public struct ReadPromoHTMLTool: SuperAgentTool {
    public let name = "app_store_promo_read_html"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Read the full index.html for a promotional image before editing it."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": PromoToolSupport.baseProperties(includeImage: true), "required": ["taskId", "imageId"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PromoToolSupport.localized(PromoToolSupport.language, en: "Read promo HTML", zh: "读取促销图 HTML")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let scope = try await PromoToolSupport.resolveScope(arguments)
        let image = try PromoToolSupport.store.readImage(
            storagePath: try await PromoToolSupport.storagePath(for: scope),
            taskSlug: try PromoToolSupport.required("taskId", arguments),
            imageSlug: try PromoToolSupport.required("imageId", arguments),
            localeIdentifier: PromoToolSupport.string(arguments, "localeIdentifier")
        )
        return "localeIdentifier=\(image.localeIdentifier) htmlPath=\(image.htmlURL.path)\n--- HTML ---\n\(image.html)"
    }
}
