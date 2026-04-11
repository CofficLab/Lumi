import Foundation
import MagicKit

/// 任务存储协议
/// Store 只负责数据存储，不执行任务
protocol TaskStoreProtocol: Actor {
    /// 认领下一个待执行的任务（从 pending → running）
    nonisolated func claimNextPendingTask() async -> UUID?

    /// 获取任务详情
    nonisolated func fetchTaskDetails(_ taskId: UUID) async -> (prompt: String, conversationId: UUID)?

    /// 更新任务状态
    nonisolated func updateTask(
        id: UUID,
        status: BackgroundAgentTaskStatus,
        resultSummary: String?,
        errorDescription: String?,
        finishedAt: Date?
    ) async
}
