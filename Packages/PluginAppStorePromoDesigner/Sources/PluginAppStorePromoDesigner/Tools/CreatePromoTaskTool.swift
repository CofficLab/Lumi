import AgentToolKit
import AppStorePromoKit
import Foundation

/// 在生成 HTML 图片之前，创建一个插件管理的促销图任务。
public struct CreatePromoTaskTool: SuperAgentTool {
    public let name = "app_store_promo_create_task"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Create one plugin-managed promotional artwork task before generating its HTML images."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = PromoToolSupport.baseProperties()
        properties["slug"] = ["type": "string", "description": "Lowercase kebab-case task slug."]
        properties["title"] = ["type": "string"]
        properties["appName"] = ["type": "string"]
        properties["deviceFamily"] = ["type": "string", "enum": ["iphone", "ipad", "mac"]]
        properties["localeIdentifier"] = ["type": "string", "description": "Locale such as en-US or zh-Hans."]
        return ["type": "object", "properties": properties, "required": ["slug", "title", "appName", "deviceFamily"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PromoToolSupport.localized(PromoToolSupport.language, en: "Create promo task", zh: "创建促销图任务")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let scope = try await PromoToolSupport.resolveScope(arguments)
        let slug = try PromoToolSupport.required("slug", arguments)
        let familyRaw = try PromoToolSupport.required("deviceFamily", arguments)
        guard let family = AppStorePromoDeviceFamily(rawValue: familyRaw.lowercased()) else {
            throw PromoToolSupport.ToolArgumentError.invalid("deviceFamily")
        }
        let task = try PromoToolSupport.store.createTask(
            storagePath: try await PromoToolSupport.storagePath(for: scope),
            slug: slug,
            title: try PromoToolSupport.required("title", arguments),
            appName: try PromoToolSupport.required("appName", arguments),
            deviceFamily: family,
            localeIdentifier: PromoToolSupport.string(arguments, "localeIdentifier") ?? "en-US"
        )
        await PromoToolSupport.notify(scope: scope, taskID: task.id)
        return "Created App Store promotional artwork task (scope=\(scope.rawValue)).\n\(PromoToolSupport.taskSummary(task, scope: scope))\nNext: create one or more HTML images with app_store_promo_create_image."
    }
}
