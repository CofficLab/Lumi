import Foundation
import KitAgentTool

/// 工具调用在宿主中的独立执行状态。
public enum ToolJobStatus: String, Codable, Sendable, Equatable {
    case queued
    case running
    case waitingForUser
    case completed
    case failed
    case cancelled
    case timedOut

    /// 判断状态是否已经结束，终态不能重新进入执行流程。
    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled, .timedOut:
            return true
        case .queued, .running, .waitingForUser:
            return false
        }
    }

    /// 判断一次状态变化是否符合工具执行生命周期。
    /// 同状态转换返回 true，便于处理重复事件而不产生错误。
    public func canTransition(to next: ToolJobStatus) -> Bool {
        if self == next { return true }
        if isTerminal { return false }

        switch self {
        case .queued:
            return next == .running
                || next == .waitingForUser
                || next == .failed
                || next == .cancelled
                || next == .timedOut
        case .running:
            return next == .waitingForUser
                || next == .completed
                || next == .failed
                || next == .cancelled
                || next == .timedOut
        case .waitingForUser:
            return next == .running
                || next == .completed
                || next == .failed
                || next == .cancelled
                || next == .timedOut
        case .completed, .failed, .cancelled, .timedOut:
            return false
        }
    }
}

/// 工具调用的可观察运行快照。
///
/// `id` 与 `toolCall.id` 保持一致，保证消息、运行状态和恢复逻辑使用同一个幂等键。
public struct ToolJob: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let conversationID: UUID
    public let turnID: UUID?
    public let toolCall: ToolCall

    public var status: ToolJobStatus
    public var createdAt: Date
    public var startedAt: Date?
    public var updatedAt: Date
    public var completedAt: Date?
    public var latestOutput: String
    public var latestProgress: ToolJobProgress?
    public var outputByteCount: Int
    public var exitCode: Int32?
    public var errorMessage: String?

    public init(
        conversationID: UUID,
        turnID: UUID? = nil,
        toolCall: ToolCall,
        status: ToolJobStatus = .queued,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        updatedAt: Date? = nil,
        completedAt: Date? = nil,
        latestOutput: String = "",
        latestProgress: ToolJobProgress? = nil,
        outputByteCount: Int = 0,
        exitCode: Int32? = nil,
        errorMessage: String? = nil
    ) {
        self.id = toolCall.id
        self.conversationID = conversationID
        self.turnID = turnID
        self.toolCall = toolCall
        self.status = status
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.updatedAt = updatedAt ?? createdAt
        self.completedAt = completedAt
        self.latestOutput = latestOutput
        self.latestProgress = latestProgress
        self.outputByteCount = outputByteCount
        self.exitCode = exitCode
        self.errorMessage = errorMessage
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case conversationID
        case turnID
        case toolCall
        case status
        case createdAt
        case startedAt
        case updatedAt
        case completedAt
        case latestOutput
        case latestProgress
        case outputByteCount
        case exitCode
        case errorMessage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let toolCall = try container.decode(ToolCall.self, forKey: .toolCall)

        // `toolCall.id` is the source of truth. Decode the legacy field only
        // to keep old snapshots readable, but never allow it to override the
        // identity used for job deduplication.
        _ = try container.decodeIfPresent(String.self, forKey: .id)
        self.id = toolCall.id
        self.conversationID = try container.decode(UUID.self, forKey: .conversationID)
        self.turnID = try container.decodeIfPresent(UUID.self, forKey: .turnID)
        self.toolCall = toolCall
        self.status = try container.decode(ToolJobStatus.self, forKey: .status)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        self.completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        self.latestOutput = try container.decode(String.self, forKey: .latestOutput)
        self.latestProgress = try container.decodeIfPresent(ToolJobProgress.self, forKey: .latestProgress)
        self.outputByteCount = try container.decode(Int.self, forKey: .outputByteCount)
        self.exitCode = try container.decodeIfPresent(Int32.self, forKey: .exitCode)
        self.errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
    }
}
