import AgentToolKit
import AppStorePromoKit
import Foundation

/// 通过复制现有语言版本，为一张促销图添加语言版本。
public struct AddPromoImageLocalizationTool: SuperAgentTool {
    public let name = "app_store_promo_add_image_language"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Add a language version to one promotional image by copying an existing version."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
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
            "properties": properties,
            "required": ["taskId", "imageId", "localeIdentifier"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PromoToolSupport.localized(PromoToolSupport.language, en: "Add promo image language", zh: "添加促销图语言版本")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let scope = try await PromoToolSupport.resolveScope(arguments)
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let imageID = try PromoToolSupport.required("imageId", arguments)
        let localized = try PromoToolSupport.store.addLocalization(
            try PromoToolSupport.required("localeIdentifier", arguments),
            copying: PromoToolSupport.string(arguments, "sourceLocaleIdentifier"),
            storagePath: try await PromoToolSupport.storagePath(for: scope),
            taskSlug: taskID,
            imageSlug: imageID
        )
        await PromoToolSupport.notify(scope: scope, taskID: taskID, imageID: imageID)
        return "Added promotional image language (scope=\(scope.rawValue), locale=\(localized.localeIdentifier)). htmlPath=\(localized.htmlURL.path)"
    }
}
