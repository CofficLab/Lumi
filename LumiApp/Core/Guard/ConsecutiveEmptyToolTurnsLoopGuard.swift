import Foundation
import MagicKit

/// 连续空 content + toolCalls 的循环保护（consecutive empty tool turns）
/// - 当 assistant 返回“空文本 content”且包含 toolCalls 时，视为一次连续计数
/// - 当连续次数达到阈值时触发 abort（并由上层决定是否产出 aborted tool messages）
struct ConsecutiveEmptyToolTurnsLoopGuard {
    enum Result {
        case proceed
        case abort(error: NSError)
    }

    func evaluate(
        hasToolCalls: Bool,
        hasContent: Bool,
        context: inout ConversationTurnContext,
        threshold: Int
    ) -> Result {
        if hasToolCalls && !hasContent {
            context.consecutiveEmptyToolTurns += 1
        } else {
            context.consecutiveEmptyToolTurns = 0
        }

        guard context.consecutiveEmptyToolTurns >= threshold else {
            return .proceed
        }

        let error = NSError(
            domain: "ConversationTurn",
            code: 409,
            userInfo: [NSLocalizedDescriptionKey: "检测到连续空响应工具循环，已自动中止本轮。"]
        )
        return .abort(error: error)
    }
}

