import Foundation
import ProviderToolManager

/// 工具调用展示与取消所需的最小工具能力。
@MainActor
public protocol MessageListToolManagerCapability: AnyObject {
    func toolCalls(for turnID: UUID) async -> [ToolCallRecord]
    /// 批量查询多个 turn 的工具调用记录。
    ///
    /// 窗口里可能有几十个 turn，逐 turn 查询会让每次刷新都退化成 N+1 次 IO。
    func toolCalls(forTurnIDs turnIDs: [UUID]) async -> [ToolCallRecord]
    func cancelJobs(forTurnID turnID: UUID)
}

@MainActor
public final class MessageListToolManagerCapabilityAdapter: MessageListToolManagerCapability {
    private let toolManager: any ToolManagerProviding
    public init(toolManager: any ToolManagerProviding) { self.toolManager = toolManager }
    public func toolCalls(for turnID: UUID) async -> [ToolCallRecord] {
        await toolManager.toolCalls(for: turnID)
    }
    public func toolCalls(forTurnIDs turnIDs: [UUID]) async -> [ToolCallRecord] {
        await toolManager.toolCalls(forTurnIDs: turnIDs)
    }
    public func cancelJobs(forTurnID turnID: UUID) {
        toolManager.cancelJobs(forTurnID: turnID)
    }
}