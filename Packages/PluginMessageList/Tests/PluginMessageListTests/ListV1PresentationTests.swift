import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageList

@MainActor
@Suite("V1 presentation")
struct ListV1PresentationTests {
    @Test("实际压缩事件作为独立行按时间插入 Agent Turn")
    func contextCompactionEventIsAnIndependentRow() {
        let conversationID = UUID()
        let olderTurn = AgentTurnPresentationItem(
            recorded: AgentTurnSummaryItem(
                record: AgentTurnRecord(
                    id: UUID(),
                    conversationID: conversationID,
                    startedAt: Date(timeIntervalSince1970: 10),
                    endedAt: Date(timeIntervalSince1970: 11),
                    state: .completed
                ),
                userMessage: nil,
                processMessages: [],
                message: Message(
                    conversationID: conversationID,
                    role: .assistant,
                    content: "完成"
                )
            ),
            acceptsLiveActivity: false
        )
        let event = Message(
            conversationID: conversationID,
            role: .system,
            content: "对话已压缩",
            createdAt: Date(timeIntervalSince1970: 20),
            metadata: [
                MessageTimelineEvent.metadataKey: MessageTimelineEvent.contextCompaction,
                MessageTimelineEvent.actualContextCompactionKey:
                    MessageTimelineEvent.actualContextCompactionValue,
            ],
            renderKind: MessageTimelineEvent.contextCompactionRenderKind
        )
        let presentation = ListV1Presentation(
            agentTurns: [olderTurn],
            timelineEvents: [event]
        )

        #expect(presentation.rows.count == 2)
        #expect(presentation.rows.first?.id == event.id)
        #expect(presentation.rows.last?.id == olderTurn.id)
    }
}
