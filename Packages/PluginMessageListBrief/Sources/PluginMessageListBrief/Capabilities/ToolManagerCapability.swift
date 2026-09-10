import Foundation
import ProviderToolManager

/// 工具调用展示与取消所需的最小工具能力。
@MainActor
protocol MessageListToolManagerCapability: AnyObject {
    func toolCalls(for turnID: UUID) async -> [ToolCallRecord]
    func cancelJobs(forTurnID turnID: UUID)
}

@MainActor
final class MessageListToolManagerCapabilityAdapter: MessageListToolManagerCapability {
    private let toolManager: any ToolManagerProviding

    init(toolManager: any ToolManagerProviding) {
        self.toolManager = toolManager
    }

    func toolCalls(for turnID: UUID) async -> [ToolCallRecord] {
        await toolManager.toolCalls(for: turnID)
    }

    func cancelJobs(forTurnID turnID: UUID) {
        toolManager.cancelJobs(forTurnID: turnID)
    }
}
