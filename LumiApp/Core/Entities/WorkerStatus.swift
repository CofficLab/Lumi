import Foundation

/// Worker 当前状态
enum WorkerStatus: Sendable, Equatable {
    /// 空闲
    case idle

    /// 正在执行指定任务
    case working(taskId: UUID)

    /// 执行失败
    case error(message: String)
}
