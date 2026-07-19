import Foundation
import LumiKernel

struct RequestLogChatMiddleware: LumiSendMiddleware {
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext {
        let systemPromptLength = context.systemPromptFragments.joined(separator: "\n").count
        RequestLogSummaryStore.append(
            RequestLogSummaryStore.Entry(
                conversationID: context.conversationID,
                messageCount: context.messages.count,
                systemPromptLength: systemPromptLength
            )
        )
        return context
    }
}
