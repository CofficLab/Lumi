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
        #expect(presentation.rows.first?.id == olderTurn.id)
        #expect(presentation.rows.last?.id == event.id)
    }

    @Test("最新 Agent Turn 显示在较早 Turn 的下方")
    func newestTurnAppearsBelowEarlierTurn() {
        let conversationID = UUID()
        let olderTurn = makeTurn(
            id: UUID(),
            conversationID: conversationID,
            startedAt: 10,
            content: "第一次发送"
        )
        let newerTurn = makeTurn(
            id: UUID(),
            conversationID: conversationID,
            startedAt: 20,
            content: "复制成功最好有一些 UI 效果"
        )

        let presentation = ListV1Presentation(agentTurns: [newerTurn, olderTurn])

        #expect(presentation.rows.map(\.id) == [olderTurn.id, newerTurn.id])
    }

    private func makeTurn(
        id: UUID,
        conversationID: UUID,
        startedAt: TimeInterval,
        content: String
    ) -> AgentTurnPresentationItem {
        AgentTurnPresentationItem(
            recorded: AgentTurnSummaryItem(
                record: AgentTurnRecord(
                    id: id,
                    conversationID: conversationID,
                    startedAt: Date(timeIntervalSince1970: startedAt),
                    endedAt: Date(timeIntervalSince1970: startedAt + 1),
                    state: .completed
                ),
                userMessage: Message(
                    conversationID: conversationID,
                    role: .user,
                    content: content,
                    createdAt: Date(timeIntervalSince1970: startedAt)
                ),
                processMessages: [],
                message: Message(
                    conversationID: conversationID,
                    role: .assistant,
                    content: "完成",
                    createdAt: Date(timeIntervalSince1970: startedAt + 1)
                )
            ),
            acceptsLiveActivity: false
        )
    }
}
