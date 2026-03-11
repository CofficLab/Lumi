import Foundation
import MagicKit
import OSLog

/// 对话轮次事件日志中间件
///
/// 用于验证 `ConversationTurnEvent` 是否按预期经过中间件链路。
@MainActor
struct ConversationTurnLoggingMiddleware: ConversationTurnMiddleware, SuperLog {
    nonisolated static let emoji = "🧾"
    nonisolated static let verbose = true

    let id: String = "plugin.agentMiddlewareDebug.logging"
    let order: Int = 500

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        if Self.verbose {
            os_log("\(Self.t) trace=\(ctx.traceId.uuidString.prefix(8)) event=\(describe(event))")
        }
        await next(event, ctx)
    }

    private func describe(_ event: ConversationTurnEvent) -> String {
        switch event {
        case .responseReceived: return "responseReceived"
        case .streamChunk: return "streamChunk"
        case .streamEvent: return "streamEvent"
        case .streamStarted: return "streamStarted"
        case .streamFinished: return "streamFinished"
        case .toolResultReceived: return "toolResultReceived"
        case .permissionRequested: return "permissionRequested"
        case .maxDepthReached: return "maxDepthReached"
        case .completed: return "completed"
        case .error: return "error"
        case .shouldContinue: return "shouldContinue"
        }
    }
}

