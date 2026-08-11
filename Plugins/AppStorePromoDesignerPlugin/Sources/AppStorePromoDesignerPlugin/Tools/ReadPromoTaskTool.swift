import AppStorePromoKit
import Foundation
import LumiKernel

public struct ReadPromoTaskTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_read_task",
        displayName: "Read promo task",
        description: "Read task metadata, image order, and available exact App Store display sizes. Searches both project and app scopes by default."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        ["type": "object", "properties": .object(PromoToolSupport.baseProperties()), "required": ["taskId"]]
    }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let taskID = try PromoToolSupport.required("taskId", arguments)
        let resolvedScope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
        let scopesToTry: [Scope] = resolvedScope == .project ? [.project, .app] : [.app]
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