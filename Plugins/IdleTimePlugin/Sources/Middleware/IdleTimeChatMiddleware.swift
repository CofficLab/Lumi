import Foundation
import LumiKernel

struct IdleTimeChatMiddleware: LumiSendMiddleware {
    func prepare(_ context: LumiSendContext) async throws -> LumiSendContext {
        await IdleTimeService.shared.record(.agentMessageSent)
        return context
    }
}
