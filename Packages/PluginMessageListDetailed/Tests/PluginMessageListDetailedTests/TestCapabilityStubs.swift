import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderConversationState
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
@testable import PluginMessageListDetailed

/// 测试用能力 stub 集合。
///
/// 这些 stub 只实现插件自己声明的窄能力协议（`Capabilities/`），不依赖任何
/// 内核 Provider，因此 ViewModel 的编排逻辑（会话切换、分页、流式、回合活动）
/// 可以在无 App 运行时、无数据库的情况下被完整驱动。
@MainActor
final class StubConversationCapability: MessageListConversationCapability {
    var selectedConversationID: UUID?
    var verbosityValue: ResponseVerbosity = .standard

    init(selectedConversationID: UUID? = nil, verbosity: ResponseVerbosity = .standard) {
        self.selectedConversationID = selectedConversationID
        self.verbosityValue = verbosity
    }

    func verbosity(for conversationID: UUID?) -> ResponseVerbosity { verbosityValue }
}

@MainActor
final class StubConversationStateCapability: MessageListConversationStateCapability {
    var snapshot: ConversationStateSnapshot

    init(snapshot: ConversationStateSnapshot) {
        self.snapshot = snapshot
    }

    func state(for conversationID: UUID) -> ConversationStateSnapshot { snapshot }
}

@MainActor
final class StubStreamingCapability: MessageListStreamingCapability {
    var stage: MessageStreamingStage = .idle
    var row: Message?

    func streamingMessage(for conversationID: UUID) -> Message? { row }
    func stage(for conversationID: UUID) -> MessageStreamingStage { stage }
}

@MainActor
final class StubToolManagerCapability: MessageListToolManagerCapability {
    var recordsByTurn: [UUID: [ToolCallRecord]] = [:]
    private(set) var cancelledTurnIDs: [UUID] = []
    private(set) var queriedTurnIDs: [UUID] = []

    func toolCalls(for turnID: UUID) async -> [ToolCallRecord] {
        queriedTurnIDs.append(turnID)
        return recordsByTurn[turnID] ?? []
    }

    func cancelJobs(forTurnID turnID: UUID) {
        cancelledTurnIDs.append(turnID)
    }
}

@MainActor
final class StubAgentLoopCapability: MessageListAgentLoopCapability {
    var state: AgentLoopState = .idle

    func state(for conversationID: UUID) -> AgentLoopState { state }
}
