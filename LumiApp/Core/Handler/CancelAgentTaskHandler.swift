import Foundation
import MagicKit

/// 响应 `AgentTaskCancellationVM` 中的取消请求，执行运行时与 UI 清理。
enum CancelAgentTaskHandler: SuperLog {
    nonisolated static let emoji = "🛑"
    nonisolated static let verbose = false

    @MainActor
    static func handle(conversationId: UUID, windowAgentCommands: WindowAgentCommands) {
        windowAgentCommands.cancelTask(for: conversationId)
    }
}
