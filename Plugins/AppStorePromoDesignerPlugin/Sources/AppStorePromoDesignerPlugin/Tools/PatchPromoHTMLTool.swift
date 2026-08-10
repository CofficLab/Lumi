import AppStorePromoKit
import Foundation
import LumiKernel

public struct PatchPromoHTMLTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_patch_html",
        displayName: "Patch promo HTML",
        description: "Apply an atomic batch of exact, unique text replacements to promotional HTML, then validate the complete result."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["operations"] = ["type": "array", "minItems": 1, "maxItems": 20, "items": ["type": "object", "properties": ["oldText": ["type": "string"], "newText": ["type": "string"]], "required": ["oldText", "newText"]]]
        return ["type": "object", "properties": .object(properties), "required": ["taskId", "imageId", "operations"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel { .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        guard case .array(let rawOperations) = arguments["operations"], !rawOperations.isEmpty, rawOperations.count <= 20 else {
            throw PromoToolSupport.ToolArgumentError.invalid("operations")
        }
        let operations = try rawOperations.map { value -> AppStorePromoPatchOperation in
            guard case .object(let object) = value,
                  let oldText = object["oldText"]?.stringValue,
                  let newText = object["newText"]?.stringValue,
                  !oldText.isEmpty else { throw PromoToolSupport.ToolArgumentError.invalid("operations") }
            return .init(oldText: oldText, newText: newText)
        }
        let scope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let imageID = try PromoToolSupport.required("imageId", arguments)
        _ = try PromoToolSupport.store.patchHTML(
            operations: operations,
            storagePath: try await PromoToolSupport.storagePath(for: scope),
            taskSlug: taskID,
            imageSlug: imageID
        )
        await PromoToolSupport.notify(scope: scope, taskID: taskID, imageID: imageID)
        return "Applied \(operations.count) HTML patches atomically (scope=\(scope.rawValue)).\nCall app_store_promo_preview_image to inspect the rendered result."
    }
}