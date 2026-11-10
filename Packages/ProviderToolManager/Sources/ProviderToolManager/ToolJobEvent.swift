import Foundation
import KitAgentTool

/// 工具 Job 的实时输出来源。
public enum ToolOutputStream: String, Codable, Sendable, Equatable {
    case stdout
    case stderr
}

/// 工具 Job 的进度快照。
public struct ToolJobProgress: Codable, Sendable, Equatable {
    public let message: String
    public let completed: Int?
    public let total: Int?
    public let fraction: Double?

    public init(
        message: String,
        completed: Int? = nil,
        total: Int? = nil,
        fraction: Double? = nil
    ) {
        self.message = message
        self.completed = completed
        self.total = total
        self.fraction = fraction
    }
}

/// Job 执行生命周期事件。
public enum ToolJobEvent: Sendable {
    /// 启动恢复完成后的历史终态 Job 快照。
    ///
    /// 恢复不走逐条 `created` 事件，因此打开中的活动面板需要这个批量快照
    /// 才能把异步恢复出来的历史任务补进列表。
    case restored([ToolJob])
    case created(ToolJob)
    case started(ToolJob)
    case output(jobID: String, stream: ToolOutputStream, chunk: String, snapshot: ToolJob)
    case progress(jobID: String, progress: ToolJobProgress, snapshot: ToolJob)
    case waitingForUser(ToolJob)
    case completed(jobID: String, result: ToolCallResult, snapshot: ToolJob)
    case failed(jobID: String, result: ToolCallResult, snapshot: ToolJob)
    case cancelled(jobID: String, result: ToolCallResult, snapshot: ToolJob)
    case timedOut(jobID: String, result: ToolCallResult, snapshot: ToolJob)
}
