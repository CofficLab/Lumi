import Foundation
import LumiKernel

struct ConversationHintMiddleware: SendMiddleware {
    func prepare(_ context: SendContext) async throws -> SendContext? {
        var updated = context
        let projectPath = context.projectPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !projectPath.isEmpty {
            updated.metadata["projectHint"] = "Current project path: \(projectPath)"
        }
        return updated
    }
}