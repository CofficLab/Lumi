import Foundation
import LumiCoreKit

@MainActor
public struct IdleTimeSendMiddleware: SuperSendMiddleware {
    public let id: String = "idle-time-activity-recorder"
    public let order: Int = 1_000

    public func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        await IdleTimeService.shared.record(.agentMessageSent)
        await next(ctx)
    }
}
