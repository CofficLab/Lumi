import KitAgentTool
import KitAppStorePromo
import Foundation

/// 读取任务元数据、图片顺序以及可用的精确 App Store 展示尺寸。
public struct ReadPromoTaskTool: SuperAgentTool {
    public let name = "app_store_promo_read_task"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Read task metadata, image order, and available exact App Store display sizes. Searches both project and app scopes by default."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": PromoToolSupport.baseProperties(), "required": ["taskId"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PromoToolSupport.localized(PromoToolSupport.language, en: "Read promo task", zh: "读取促销图任务")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let resolvedScope = try await PromoToolSupport.resolveScope(arguments)
        let scopesToTry: [PromoScope] = resolvedScope == .project ? [.project, .app] : [.app]
        var lastError: Error?
        for scope in scopesToTry {
            let path = try await PromoToolSupport.storagePath(for: scope)
            do {
                let task = try PromoToolSupport.store.readTask(storagePath: path, taskSlug: taskID)
                return PromoToolSupport.taskSummary(task, scope: scope)
            } catch {
                lastError = error
            }
        }
        throw lastError ?? PromoToolSupport.ToolArgumentError.invalid("taskId")
    }
}
