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
    private let conversationProjectPathProvider: @MainActor @Sendable () async -> String?

    public init(
        jobID: String,
        conversationID: UUID,
        turnID: UUID? = nil,
        isCancelled: @escaping @Sendable () -> Bool = { false },
        reportOutput: @escaping @Sendable (ToolExecutionOutputStream, String) async -> Void = { _, _ in },
        reportProgress: @escaping @Sendable (ToolExecutionProgress) async -> Void = { _ in },
        conversationProjectPathProvider: @escaping @MainActor @Sendable () async -> String? = { nil }
    ) {
        self.jobID = jobID
        self.conversationID = conversationID
        self.turnID = turnID
        self.isCancelled = isCancelled
        self.reportOutput = reportOutput
        self.reportProgress = reportProgress
        self.conversationProjectPathProvider = conversationProjectPathProvider
    }

    /// Resolves the project bound to this tool call's conversation, independent
    /// of whichever conversation is currently selected in the UI.
    public func conversationProjectPath() async -> String? {
        guard let path = await conversationProjectPathProvider()?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }
        return path
    }
}
