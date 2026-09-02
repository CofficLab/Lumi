import Foundation
import KitAgentTool

/// 可恢复 Tool Job 的持久化快照。
///
/// 它和 `ToolCallRecord` 有不同语义：ToolCallRecord 是完成后的历史日志，
/// ToolJobRecord 是执行期间以及终态都需要保留的运行状态。
public struct ToolJobRecord: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let conversationID: UUID
    public let turnID: UUID?
    public let toolName: String
    public let argumentsJSON: String
    public let argumentsHash: String

    public var status: ToolJobStatus
    public var createdAt: Date
    public var startedAt: Date?
    public var updatedAt: Date
    public var latestOutput: String
    public var outputByteCount: Int
    public var processID: Int32?
    public var cancelRequested: Bool
    public var completedAt: Date?
    public var result: ToolCallResult?
    public var errorMessage: String?

    public init(
        id: String,
        conversationID: UUID,
        turnID: UUID?,
        toolName: String,
        argumentsJSON: String,
        argumentsHash: String = "",
        status: ToolJobStatus,
        createdAt: Date,
        startedAt: Date? = nil,
        updatedAt: Date,
        latestOutput: String = "",
        outputByteCount: Int = 0,
        processID: Int32? = nil,
        cancelRequested: Bool = false,
        completedAt: Date? = nil,
        result: ToolCallResult? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.turnID = turnID
        self.toolName = toolName
        self.argumentsJSON = argumentsJSON
        self.argumentsHash = argumentsHash
        self.status = status
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.latestOutput = latestOutput
        self.outputByteCount = outputByteCount
        self.processID = processID
        self.cancelRequested = cancelRequested
        self.completedAt = completedAt
        self.result = result
        self.errorMessage = errorMessage
    }

    /// 统一生成参数指纹，避免把完整参数内容用于幂等比较。
    public static func makeArgumentsHash(_ argumentsJSON: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in argumentsJSON.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}
