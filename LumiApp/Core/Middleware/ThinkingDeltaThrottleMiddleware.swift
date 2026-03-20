import Foundation
import MagicKit

/// 思考增量节流中间件
///
/// **设计原则**：节流仅针对 UI 刷新，不影响内容累积的完整性。
///
/// 工作流程：
/// 1. 所有 `.thinkingDelta` 事件都会传递到下游（确保内容完整累积到 `runtimeStore.thinkingTextByConversation`）
/// 2. UI 刷新节流由下游的 `ThinkingDeltaCaptureMiddleware` 通过 `flushPendingThinkingText` 处理
/// 3. 这样既保证了落库内容的完整性，又避免了 SwiftUI 的频繁刷新
///
/// ## 节流参数
///
/// - `minInterval`: UI 刷新的最小时间间隔（默认 0.12 秒）
///
/// ## 注意事项
///
/// - 绝对不要短路 `.thinkingDelta` 事件，否则会导致内容丢失
@MainActor
final class ThinkingDeltaThrottleMiddleware: ConversationTurnMiddleware, SuperLog {
    nonisolated static let emoji = "🧠"
    nonisolated static let verbose = true

    let id: String = "core.thinkingDeltaThrottle"
    let order: Int = 5

    private var lastForwardAtByConversation: [UUID: Date] = [:]
    private let minInterval: TimeInterval

    init(minInterval: TimeInterval = 0.12) {
        self.minInterval = minInterval
    }

    func handle(
        event: ConversationTurnEvent,
        ctx: ConversationTurnMiddlewareContext,
        next: @escaping @MainActor (ConversationTurnEvent, ConversationTurnMiddlewareContext) async -> Void
    ) async {
        guard case let .streamEvent(eventType, _, _, _, conversationId) = event,
              eventType == .thinkingDelta else {
            await next(event, ctx)
            return
        }

        // 关键：所有 thinking delta 事件都必须传递到下游，确保内容完整累积
        // UI 节流由下游的 ThinkingDeltaCaptureMiddleware 通过 flushPendingThinkingText 处理

        let now = Date()
        if let last = lastForwardAtByConversation[conversationId],
           now.timeIntervalSince(last) < minInterval {
            // 事件仍然传递到下游，只是记录时间戳用于统计
            if Self.verbose {
                AppLogger.core.info("\(Self.t) 节流传递（<\(String(format: "%.2f", self.minInterval))s)")
            }
            await next(event, ctx)
            return
        }

        lastForwardAtByConversation[conversationId] = now
        if Self.verbose {
            AppLogger.core.info("\(Self.t) 放行 thinking delta")
        }
        await next(event, ctx)
    }
}

