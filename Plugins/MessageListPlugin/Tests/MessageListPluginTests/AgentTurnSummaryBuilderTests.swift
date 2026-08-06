import Foundation
import LumiKernel
import Testing
@testable import MessageListPlugin

struct AgentTurnSummaryBuilderTests {
    private let conversationID = UUID()
    private let builder = AgentTurnSummaryBuilder()

    @Test("完成的 Turn 只展示最终回答")
    func completedTurnUsesFinalAssistantResponse() throws {
        let turnID = UUID()
        let process = message(
            turnID: turnID,
            content: "calling a tool",
            toolCalls: [LumiToolCall(id: "tool", name: "search", arguments: "{}")],
            offset: 1
        )
        let tool = message(turnID: turnID, role: .tool, content: "tool output", offset: 2)
        let final = message(turnID: turnID, content: "final summary", offset: 3)

        let items = builder.build(
            records: [record(id: turnID, state: .completed, offset: 0)],
            messages: [process, tool, final]
        )

        #expect(items.count == 1)
        #expect(items.first?.message.id == final.id)
    }

    @Test("失败的 Turn 展示错误消息")
    func failedTurnUsesErrorMessage() throws {
        let turnID = UUID()
        let process = message(turnID: turnID, content: "partial response", offset: 1)
        let error = message(turnID: turnID, role: .error, content: "request failed", offset: 2)

        let items = builder.build(
            records: [record(id: turnID, state: .failed, offset: 0)],
            messages: [process, error]
        )

        #expect(items.first?.message.id == error.id)
    }

    @Test("历史失败 Turn 即使被聚合为 completed 也展示末尾错误")
    func completedHistoricalTurnUsesLaterError() throws {
        let turnID = UUID()
        let partial = message(turnID: turnID, content: "partial response", offset: 1)
        let error = message(turnID: turnID, role: .error, content: "request failed", offset: 2)

        let items = builder.build(
            records: [record(id: turnID, state: .completed, offset: 0)],
            messages: [partial, error]
        )

        #expect(items.first?.message.id == error.id)
    }

    @Test("暂停的 Turn 保留最后一条可见助手消息")
    func suspendedTurnUsesLatestVisibleAssistantMessage() throws {
        let turnID = UUID()
        let prompt = message(
            turnID: turnID,
            content: "choose an option",
            toolCalls: [LumiToolCall(id: "ask", name: "ask_user", arguments: "{}")],
            offset: 1
        )
        let suspension = AgentTurnSuspension(
            suspensionID: "suspension",
            conversationID: conversationID,
            kind: "ask_user",
            payload: "{}"
        )

        let items = builder.build(
            records: [record(id: turnID, state: .suspended(suspension), offset: 0)],
            messages: [prompt]
        )

        #expect(items.first?.message.id == prompt.id)
    }

    @Test("没有关联消息的 Turn 不生成空白行，结果按时间正序")
    func omitsMissingMessagesAndSortsChronologically() throws {
        let olderTurnID = UUID()
        let newerTurnID = UUID()
        let missingTurnID = UUID()
        let olderMessage = message(turnID: olderTurnID, content: "older", offset: 2)
        let newerMessage = message(turnID: newerTurnID, content: "newer", offset: 4)

        let items = builder.build(
            records: [
                record(id: newerTurnID, state: .completed, offset: 3),
                record(id: missingTurnID, state: .completed, offset: 1),
                record(id: olderTurnID, state: .completed, offset: 0),
            ],
            messages: [newerMessage, olderMessage]
        )

        #expect(items.map(\.record.id) == [olderTurnID, newerTurnID])
    }

    private func record(id: UUID, state: AgentTurnState, offset: TimeInterval) -> AgentTurnRecord {
        AgentTurnRecord(
            id: id,
            conversationID: conversationID,
            state: state,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000 + offset)
        )
    }

    private func message(
        turnID: UUID,
        role: LumiChatMessageRole = .assistant,
        content: String,
        toolCalls: [LumiToolCall]? = nil,
        offset: TimeInterval
    ) -> LumiChatMessage {
        LumiChatMessage(
            conversationID: conversationID,
            role: role,
            content: content,
            turnID: turnID,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000 + offset),
            toolCalls: toolCalls
        )
    }
}
