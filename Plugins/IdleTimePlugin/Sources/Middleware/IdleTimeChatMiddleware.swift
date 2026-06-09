import Foundation
import LumiCoreKit

struct IdleTimeChatMiddleware: LumiSendMiddleware {
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext {
        await IdleTimeService.shared.record(.agentMessageSent)
        return context
    }
}
