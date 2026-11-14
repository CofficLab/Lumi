import Foundation
import Testing
@testable import PluginConversationResume
import ProviderMessage

@MainActor
struct OrphanToolCallScannerTests {
    // MARK: - 辅助

    private func assistant(
        toolCalls: [MessageToolCall],
        turnID: UUID? = nil
    ) -> Message {
        Message(
            conversationID: UUID(),
            role: .assistant,
            content: "",
            turnID: turnID,
            toolCalls: toolCalls
        )
    }

    private func toolResult(toolCallID: String, turnID: UUID? = nil) -> Message {
        Message(
            conversationID: UUID(),
            role: .tool,
            content: "ok",
            turnID: turnID,
            toolCallID: toolCallID
        )
    }

    private func toolCall(id: String, name: String = "read_file") -> MessageToolCall {
        MessageToolCall(id: id, name: name, arguments: "{}")
    }

    // MARK: - 扫描

    @Test("没有工具调用时没有孤儿")
    func noToolCallsNoOrphans() {
        let orphans = OrphanToolCallScanner.scan([
            Message(conversationID: UUID(), role: .user, content: "hi"),
            Message(conversationID: UUID(), role: .assistant, content: "hello"),
        ])
        #expect(orphans.isEmpty)
    }

    @Test("工具调用缺少 tool result 时被识别为孤儿")
    func missingResultIsOrphan() {
        let turnID = UUID()
        let orphans = OrphanToolCallScanner.scan([
            assistant(toolCalls: [toolCall(id: "call_1")], turnID: turnID)
        ])

        #expect(orphans.count == 1)
        #expect(orphans[0].toolCall.id == "call_1")
        #expect(orphans[0].turnID == turnID)
    }

    @Test("已配对的工具调用不是孤儿")
    func pairedToolCallIsNotOrphan() {
        let turnID = UUID()
        let orphans = OrphanToolCallScanner.scan([
            assistant(toolCalls: [toolCall(id: "call_1")], turnID: turnID),
            toolResult(toolCallID: "call_1", turnID: turnID),
        ])

        #expect(orphans.isEmpty)
    }

    @Test("部分配对时只报告未配对的那个")
    func partiallyPairedReportsOnlyUnpaired() {
        let turnID = UUID()
        let orphans = OrphanToolCallScanner.scan([
            assistant(toolCalls: [toolCall(id: "call_1"), toolCall(id: "call_2")], turnID: turnID),
            toolResult(toolCallID: "call_1", turnID: turnID),
        ])

        #expect(orphans.count == 1)
        #expect(orphans[0].toolCall.id == "call_2")
    }

    @Test("跨回合的 tool result 不能配对另一个回合的 tool_call")
    func crossTurnResultDoesNotPair() {
        let turnA = UUID()
        let turnB = UUID()
        let orphans = OrphanToolCallScanner.scan([
            assistant(toolCalls: [toolCall(id: "call_1")], turnID: turnB),
            toolResult(toolCallID: "call_1", turnID: turnA),
        ])

        #expect(orphans.count == 1)
        #expect(orphans[0].turnID == turnB)
    }

    @Test("展示快照里已有结果的工具调用不算孤儿")
    func snapshotWithResultIsNotOrphan() {
        var call = toolCall(id: "call_1")
        call.result = MessageToolResult(content: "done")
        let orphans = OrphanToolCallScanner.scan([
            assistant(toolCalls: [call]),
        ])

        #expect(orphans.isEmpty)
    }

    // MARK: - 占位消息

    @Test("占位消息补上 tool_call_id 与错误标记")
    func placeholderMessageCarriesToolCallID() {
        let orphan = OrphanToolCall(
            assistantMessageID: UUID(),
            toolCall: toolCall(id: "call_9"),
            turnID: UUID()
        )
        let conversationID = UUID()

        let message = OrphanToolCallRepair.placeholderMessage(
            for: orphan,
            conversationID: conversationID
        )

        #expect(message.role == .tool)
        #expect(message.toolCallID == "call_9")
        #expect(message.isError)
        #expect(message.conversationID == conversationID)
        #expect(message.turnID == orphan.turnID)
        #expect(message.content == OrphanToolCallRepair.placeholderContent)
    }

    @Test("占位正文明确说明结果未知")
    func placeholderContentStatesOutcomeUnknown() {
        #expect(OrphanToolCallRepair.placeholderContent.contains("unknown"))
        #expect(OrphanToolCallRepair.placeholderContent.contains("interrupted"))
    }

    @Test("修复后重新扫描不再有孤儿")
    func repairRemovesOrphans() {
        let turnID = UUID()
        let conversationID = UUID()
        let history = [
            Message(
                conversationID: conversationID,
                role: .assistant,
                content: "",
                turnID: turnID,
                toolCalls: [toolCall(id: "call_1")]
            )
        ]

        let orphans = OrphanToolCallScanner.scan(history)
        #expect(orphans.count == 1)

        let repaired = history + OrphanToolCallRepair.placeholderMessages(
            for: orphans,
            in: history,
            conversationID: conversationID
        )

        #expect(OrphanToolCallScanner.scan(repaired).isEmpty)
    }

    // MARK: - 占位消息插入位置（#636）

    @Test("孤儿调用之后已有用户消息时，占位插在 assistant 与用户消息之间")
    func placeholderLandsBetweenAssistantAndLaterUserMessage() {
        let conversationID = UUID()
        let turnID = UUID()
        let user1 = Message(
            conversationID: conversationID, role: .user, content: "U1",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let assistant = Message(
            conversationID: conversationID, role: .assistant, content: "",
            createdAt: Date(timeIntervalSince1970: 2_000),
            turnID: turnID, toolCalls: [toolCall(id: "call_1")]
        )
        let user2 = Message(
            conversationID: conversationID, role: .user, content: "U2",
            createdAt: Date(timeIntervalSince1970: 3_000)
        )
        let history = [user1, assistant, user2]

        let orphans = OrphanToolCallScanner.scan(history)
        let repaired = (history + OrphanToolCallRepair.placeholderMessages(
            for: orphans,
            in: history,
            conversationID: conversationID
        )).sorted { $0.createdAt < $1.createdAt }

        #expect(repaired.map(\.id) == [user1.id, assistant.id, repaired[2].id, user2.id])
        #expect(repaired[2].role == .tool)
        #expect(repaired[2].toolCallID == "call_1")
        #expect(repaired[2].createdAt > assistant.createdAt)
        #expect(repaired[2].createdAt < user2.createdAt)
    }

    @Test("占位插在所属 assistant 的已有工具结果之后")
    func placeholderFollowsExistingToolResultOfSameAssistant() {
        let conversationID = UUID()
        let turnID = UUID()
        let assistant = Message(
            conversationID: conversationID, role: .assistant, content: "",
            createdAt: Date(timeIntervalSince1970: 2_000),
            turnID: turnID, toolCalls: [toolCall(id: "call_1"), toolCall(id: "call_2")]
        )
        let result1 = Message(
            conversationID: conversationID, role: .tool, content: "ok",
            createdAt: Date(timeIntervalSince1970: 2_500),
            turnID: turnID, toolCallID: "call_1"
        )
        let user2 = Message(
            conversationID: conversationID, role: .user, content: "U2",
            createdAt: Date(timeIntervalSince1970: 3_000)
        )
        let history = [assistant, result1, user2]

        let orphans = OrphanToolCallScanner.scan(history)
        #expect(orphans.count == 1)
        let repaired = (history + OrphanToolCallRepair.placeholderMessages(
            for: orphans,
            in: history,
            conversationID: conversationID
        )).sorted { $0.createdAt < $1.createdAt }

        #expect(repaired.map(\.id) == [assistant.id, result1.id, repaired[2].id, user2.id])
        #expect(repaired[2].toolCallID == "call_2")
        #expect(repaired[2].createdAt > result1.createdAt)
        #expect(repaired[2].createdAt < user2.createdAt)
    }

    @Test("assistant 是最后一条消息时占位按当前时间追加")
    func placeholderAppendsWhenAssistantIsLast() {
        let conversationID = UUID()
        let turnID = UUID()
        let assistant = Message(
            conversationID: conversationID, role: .assistant, content: "",
            createdAt: Date(timeIntervalSince1970: 2_000),
            turnID: turnID, toolCalls: [toolCall(id: "call_1")]
        )
        let history = [assistant]

        let orphans = OrphanToolCallScanner.scan(history)
        let placeholders = OrphanToolCallRepair.placeholderMessages(
            for: orphans,
            in: history,
            conversationID: conversationID
        )

        #expect(placeholders.count == 1)
        #expect(placeholders[0].createdAt >= assistant.createdAt)
        #expect(OrphanToolCallScanner.scan(history + placeholders).isEmpty)
    }
}
