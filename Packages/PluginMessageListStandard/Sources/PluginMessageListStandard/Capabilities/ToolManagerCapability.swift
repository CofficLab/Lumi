import Foundation
import ProviderToolManager

/// 工具调用展示与取消所需的最小工具能力。
@MainActor
protocol MessageListToolManagerCapability: AnyObject {
    func toolCalls(for turnID: UUID) async -> [ToolCallRecord]
    /// 批量查询多个 turn 的工具调用记录。
    ///
    /// 窗口里可能有几十个 turn，逐 turn 查询会让每次刷新都退化成 N+1 次 IO。
    func toolCalls(forTurnIDs turnIDs: [UUID]) async -> [ToolCallRecord]
    func cancelJobs(forTurnID turnID: UUID)
}

@MainActor
final class MessageListToolManagerCapabilityAdapter: MessageListToolManagerCapability {
    private let toolManager: any ToolManagerProviding
    init(toolManager: any ToolManagerProviding) { self.toolManager = toolManager }
    func toolCalls(for turnID: UUID) async -> [ToolCallRecord] {
        await toolManager.toolCalls(for: turnID)
    }
    func toolCalls(forTurnIDs turnIDs: [UUID]) async -> [ToolCallRecord] {
        await toolManager.toolCalls(forTurnIDs: turnIDs)
    }
    func cancelJobs(forTurnID turnID: UUID) {
        toolManager.cancelJobs(forTurnID: turnID)
    }
}