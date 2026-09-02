import Foundation

/// 工具执行期间可使用的输出流类型。
public enum ToolExecutionOutputStream: String, Codable, Sendable, Equatable {
    case stdout
    case stderr
}

/// 工具执行期间上报的进度快照。
public struct ToolExecutionProgress: Codable, Sendable, Equatable {
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

/// 工具执行时与宿主通信的最小上下文。
public struct ToolExecutionContext: Sendable {
    public let jobID: String
    public let conversationID: UUID
    public let turnID: UUID?
    public let isCancelled: @Sendable () -> Bool
    public let reportOutput: @Sendable (ToolExecutionOutputStream, String) async -> Void
    public let reportProgress: @Sendable (ToolExecutionProgress) async -> Void

    public init(
        jobID: String,
        conversationID: UUID,
        turnID: UUID? = nil,
        isCancelled: @escaping @Sendable () -> Bool = { false },
        reportOutput: @escaping @Sendable (ToolExecutionOutputStream, String) async -> Void = { _, _ in },
        reportProgress: @escaping @Sendable (ToolExecutionProgress) async -> Void = { _ in }
    ) {
        self.jobID = jobID
        self.conversationID = conversationID
        self.turnID = turnID
        self.isCancelled = isCancelled
        self.reportOutput = reportOutput
        self.reportProgress = reportProgress
    }
}
