import Foundation
import SwiftData

// MARK: - TaskStoreProtocol

/// 任务存储协议
/// 用于 Worker 依赖注入，避免循环引用
protocol TaskStoreProtocol: Actor {
    /// 认领下一个待执行的任务
    func claimNextPendingTask() -> UUID?
    
    /// 执行任务
    func performTask(taskId: UUID) async throws -> (summary: String, error: Error?)
    
    /// 更新任务状态
    func updateTask(
        id: UUID,
        status: BackgroundAgentTaskStatus,
        resultSummary: String?,
        errorDescription: String?,
        finishedAt: Date?
    )
}
