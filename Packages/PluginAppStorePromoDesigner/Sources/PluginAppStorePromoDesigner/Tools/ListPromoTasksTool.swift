import KitAgentTool
import KitAppStorePromo
import Foundation

/// 列出插件管理的促销图任务，跨 project / app 两个作用域。
public struct ListPromoTasksTool: SuperAgentTool {
    public let name = "app_store_promo_list_tasks"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "List plugin-managed App Store promotional artwork tasks and their images, across project and app scopes."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "scope": [
                    "type": "string",
                    "enum": ["all"] + PromoScope.allCases.map(\.rawValue),
                    "description": "Filter by scope: 'project', 'app', or 'all' (default).",
                ],
            ],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PromoToolSupport.localized(PromoToolSupport.language, en: "List promo tasks", zh: "列出促销图任务")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let scopeFilter = (PromoToolSupport.string(arguments, "scope") ?? "all")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let snapshot = await MainActor.run { () -> [(PromoScope, [AppStorePromoTask])] in
            let store = WorkspaceStore.shared
            var result: [(PromoScope, [AppStorePromoTask])] = []
            if scopeFilter == "all" || scopeFilter == PromoScope.project.rawValue {
                result.append((.project, store.projectTasks))
            }
            if scopeFilter == "all" || scopeFilter == PromoScope.app.rawValue {
                result.append((.app, store.appTasks))
            }
            return result
        }
        let lines = snapshot.flatMap { scope, tasks in
            tasks.isEmpty ? ["[scope=\(scope.rawValue)] (no tasks)"] : tasks.map { PromoToolSupport.taskSummary($0, scope: scope) }
        }
        if lines.isEmpty {
            return "No App Store promotional artwork tasks found."
        }
        return lines.joined(separator: "\n")
    }
}
