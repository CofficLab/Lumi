import AppStorePromoKit
import Foundation
import KernelLumi

public struct CreatePromoTaskTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_create_task",
        displayName: "Create promo task",
        description: "Create one plugin-managed promotional artwork task before generating its HTML images."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties: [String: LumiJSONValue] = PromoToolSupport.baseProperties()
        properties["slug"] = ["type": "string", "description": "Lowercase kebab-case task slug."]
        properties["title"] = ["type": "string"]
        properties["appName"] = ["type": "string"]
        properties["deviceFamily"] = ["type": "string", "enum": ["iphone", "ipad", "mac"]]
        properties["localeIdentifier"] = ["type": "string", "description": "Locale such as en-US or zh-Hans."]
        return ["type": "object", "properties": .object(properties), "required": ["slug", "title", "appName", "deviceFamily"]]
    }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel { .medium }
    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let scope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
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
            localeIdentifier: arguments.string("localeIdentifier") ?? "en-US"
        )
        await PromoToolSupport.notify(scope: scope, taskID: task.id)
        return "Created App Store promotional artwork task (scope=\(scope.rawValue)).\n\(PromoToolSupport.taskSummary(task, scope: scope))\nNext: create one or more HTML images with app_store_promo_create_image."
    }
}