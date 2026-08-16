import AgentToolKit
import AppStorePromoKit
import Foundation

/// 对促销图 HTML 应用一批精确、唯一的文本替换（原子操作），然后校验完整结果。
public struct PatchPromoHTMLTool: SuperAgentTool {
    public let name = "app_store_promo_patch_html"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Apply an atomic batch of exact, unique text replacements to promotional HTML, then validate the complete result."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["operations"] = [
            "type": "array",
            "minItems": 1,
            "maxItems": 20,
            "items": [
                "type": "object",
                "properties": ["oldText": ["type": "string"], "newText": ["type": "string"]],
                "required": ["oldText", "newText"],
            ],
        ]
        return ["type": "object", "properties": properties, "required": ["taskId", "imageId", "operations"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PromoToolSupport.localized(PromoToolSupport.language, en: "Patch promo HTML", zh: "修补促销图 HTML")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let rawOperations = arguments["operations"]?.value as? [Any],
              !rawOperations.isEmpty, rawOperations.count <= 20 else {
            throw PromoToolSupport.ToolArgumentError.invalid("operations")
        }
        let operations = try rawOperations.map { value -> AppStorePromoPatchOperation in
            guard let object = value as? [String: Any],
                  let oldText = object["oldText"] as? String,
                  let newText = object["newText"] as? String,
                  !oldText.isEmpty else { throw PromoToolSupport.ToolArgumentError.invalid("operations") }
            return .init(oldText: oldText, newText: newText)
        }
        let scope = try await PromoToolSupport.resolveScope(arguments)
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let imageID = try PromoToolSupport.required("imageId", arguments)
        _ = try PromoToolSupport.store.patchHTML(
            operations: operations,
            storagePath: try await PromoToolSupport.storagePath(for: scope),
            taskSlug: taskID,
            imageSlug: imageID,
            localeIdentifier: PromoToolSupport.string(arguments, "localeIdentifier")
        )
        await PromoToolSupport.notify(scope: scope, taskID: taskID, imageID: imageID)
        return "Applied \(operations.count) HTML patches atomically (scope=\(scope.rawValue), locale=\(PromoToolSupport.string(arguments, "localeIdentifier") ?? "primary")).\nCall app_store_promo_preview_image to inspect the rendered result."
    }
}
