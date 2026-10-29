import KitAgentTool
import KitAppStorePromo
import Foundation

/// 列出当前项目内由插件管理的促销图任务。
public struct ListPromoTasksTool: SuperAgentTool {
    public let name = "app_store_promo_list_tasks"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "List plugin-managed App Store promotional artwork tasks and their images in the current project."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [:],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PromoToolSupport.localized(PromoToolSupport.language, en: "List promo tasks", zh: "列出促销图任务")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        // 直接读当前调用所属项目的存储，而不是 UI 全局缓存——
        // 后者跟随「当前打开项目」，在多对话并行时会串项目。
        let tasks = try PromoToolSupport.store.listTasks(
            storagePath: try await PromoToolSupport.storagePath()
        )
        let lines = tasks.map { PromoToolSupport.taskSummary($0) }
        if lines.isEmpty {
            return "No App Store promotional artwork tasks found."
        }
        return lines.joined(separator: "\n")
    }
}
