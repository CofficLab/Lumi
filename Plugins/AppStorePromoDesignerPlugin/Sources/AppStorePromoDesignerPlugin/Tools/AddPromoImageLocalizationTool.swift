import AppStorePromoKit
import KernelLumi

public struct AddPromoImageLocalizationTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_add_image_language",
        displayName: "Add promo image language",
        description: "Add a language version to one promotional image by copying an existing version."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["localeIdentifier"] = [
            "type": "string",
            "description": "Language version to add, such as zh-Hans or ja."
        ]
        properties["sourceLocaleIdentifier"] = [
            "type": "string",
            "description": "Optional existing language to copy. Defaults to the primary language."
        ]
        return [
            "type": "object",
            "properties": .object(properties),
            "required": ["taskId", "imageId", "localeIdentifier"]
        ]
    }

    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel { .medium }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let scope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let imageID = try PromoToolSupport.required("imageId", arguments)
        let localized = try PromoToolSupport.store.addLocalization(
            try PromoToolSupport.required("localeIdentifier", arguments),
            copying: arguments.string("sourceLocaleIdentifier"),
            storagePath: try await PromoToolSupport.storagePath(for: scope),
            taskSlug: taskID,
            imageSlug: imageID
        )
        await PromoToolSupport.notify(scope: scope, taskID: taskID, imageID: imageID)
        return "Added promotional image language (scope=\(scope.rawValue), locale=\(localized.localeIdentifier)). htmlPath=\(localized.htmlURL.path)"
    }
}
