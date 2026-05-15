import Foundation

@MainActor
struct IdleTimeSendMiddleware: SuperSendMiddleware {
    let id: String = "idle-time-activity-recorder"
    let order: Int = 1_000

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        await IdleTimeService.shared.record(.agentMessageSent)
        await next(ctx)
    }
}
