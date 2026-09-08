import Foundation
import ProviderMessage
import ProviderMessageStreaming
import Testing
@testable import PluginMessageList

@MainActor
@Suite("V1 streaming projection")
struct AgentTurnViewModelTests {
    @Test("V1 不把流式临时回复加入展示投影")
    func streamingMessageIsNotProjected() {
        let conversationID = UUID()
        let turnID = UUID()
        let item = AgentTurnPresentationItem(
            recorded: AgentTurnSummaryItem(
                record: AgentTurnRecord(
                    id: turnID,
                    conversationID: conversationID,
                    startedAt: Date(timeIntervalSince1970: 10),
                    endedAt: nil,
                    state: .running
                ),
                userMessage: nil,
                processMessages: [],
                message: Message(
                    conversationID: conversationID,
                    role: .status,
                    content: "…",
                    createdAt: Date(timeIntervalSince1970: 10),
                    turnID: turnID
                )
            ),
            acceptsLiveActivity: true
        )
        let streamingMessage = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "正在生成的半截回复",
            createdAt: Date(timeIntervalSince1970: 11),
            turnID: turnID
        )

        let projection = AgentTurnViewModel.project(
            item: item,
            messages: [],
            streamingMessage: streamingMessage,
            streamingStage: .generating
        )

        #expect(projection.lastMessage == nil)
        #expect(projection.processMessages.isEmpty)
        #expect(projection.activityMessage?.content == "正在生成回复…")
    }
}
