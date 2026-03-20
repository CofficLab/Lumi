import Foundation
import MagicKit

@MainActor
struct TraceLoggingMiddleware: ConversationTurnMiddleware, SuperLog {
    nonisolated static let emoji = "🧭"
    nonisolated static let verbose = false

    let id: String = "core.traceLogging"
    let order: Int = 10

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        let start = CFAbsoluteTimeGetCurrent()
        if Self.verbose {
            AppLogger.core.info("\(Self.t) trace=\(ctx.traceId.uuidString.prefix(8)) event=\(describe(event))")
        }

        await next(event, ctx)

        let elapsed = CFAbsoluteTimeGetCurrent() - start
        if Self.verbose, elapsed > 0.5 {
            AppLogger.core.error("\(Self.t) trace=\(ctx.traceId.uuidString.prefix(8)) 中间件耗时偏高=\(elapsed)s event=\(describe(event))")
        }
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
        case .permissionDecision: return "permissionDecision"
        case .maxDepthReached: return "maxDepthReached"
        case .completed: return "completed"
        case .error: return "error"
        case .shouldContinue: return "shouldContinue"
        }
    }
}

