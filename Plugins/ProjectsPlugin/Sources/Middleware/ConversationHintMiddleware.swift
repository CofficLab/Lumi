import Foundation
import LumiCoreKit

struct ConversationHintMiddleware: LumiSendMiddleware {
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext {
        var updated = context
        let projectPath = context.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !projectPath.isEmpty {
            updated.systemPromptFragments.append("Current project path: \(projectPath)")
        }
        return updated
    }
}
