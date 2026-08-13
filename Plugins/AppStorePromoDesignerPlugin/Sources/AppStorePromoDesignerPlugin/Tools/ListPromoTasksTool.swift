import AppStorePromoKit
import Foundation
import KernelLumi

public struct ListPromoTasksTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_list_tasks",
        displayName: "List promo tasks",
        description: "List plugin-managed App Store promotional artwork tasks and their images, across project and app scopes."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        [
            "type": "object",
            "properties": [
                "scope": [
                    "type": "string",
                    "enum": .array(["all"] + Scope.allCases.map { .string($0.rawValue) }),
                    "description": "Filter by scope: 'project', 'app', or 'all' (default).",
                ],
            ],
        ]
    }
    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let scopeFilter = (arguments.string("scope") ?? "all").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let snapshot = await MainActor.run { () -> [(Scope, [AppStorePromoTask])] in
            let store = WorkspaceStore.shared
            var result: [(Scope, [AppStorePromoTask])] = []
            if scopeFilter == "all" || scopeFilter == Scope.project.rawValue {
                result.append((.project, store.projectTasks))
            }
            if scopeFilter == "all" || scopeFilter == Scope.app.rawValue {
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