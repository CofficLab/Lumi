import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageListDetailed

/// Detailed 把「只含工具调用的助手消息」合成一行时，必须保留思考内容（回归 #148）。
///
/// ## 为什么要有这条测试
///
/// `makeToolStepGroup` 合成展示消息时复制了 id/content/toolCalls/metadata 等字段，
/// 却唯独没有传 `reasoningContent`。于是支持思考输出的模型在工具调用阶段的
/// 思考内容在展示层凭空消失——即使组内只有一条消息，它的思考也变成 nil。
///
/// 合成只在展示层发生，不落库、不进 LLM 历史；这里锁定的是展示行必须把成员
/// 的思考内容原样带出来：单条原样保留，多条按时间顺序合并，不丢失任何一段。
private func makeToolOnlyMessage(
    id: UUID,
    conversationID: UUID,
    turnID: UUID?,
    toolCallID: String,
    createdAt: Date,
    reasoningContent: String?
) -> Message {
    Message(
        id: id,
        conversationID: conversationID,
        role: .assistant,
        content: "",
        createdAt: createdAt,
        turnID: turnID,
        reasoningContent: reasoningContent,
        toolCalls: [
            MessageToolCall(
                id: toolCallID,
                name: "run_command",
                arguments: "{}",
                result: MessageToolResult(content: "result of \(toolCallID)"),
                displayDescription: "运行 \(toolCallID)"
            )
        ]
    )
}

@MainActor
@Suite("Detailed 工具组合成保留思考内容")
struct MessageListToolGroupReasoningTests {

    @Test("单条工具消息合成后原样保留 reasoningContent")
    func singleMemberToolGroupPreservesReasoningContent() {
        let conversationID = UUID()
        let turnID = UUID()
        let base = Date(timeIntervalSince1970: 1_000)
        let builder = MessageListRowBuilder()

        let message = makeToolOnlyMessage(
            id: UUID(), conversationID: conversationID, turnID: turnID,
            toolCallID: "c1", createdAt: base, reasoningContent: "思考过程 R"
        )

        let rows = builder.buildHistory(
            persisted: [message],
            conversationID: conversationID,
            verbosity: .standard
        )

        #expect(rows.count == 1, "单条工具消息应合成 1 行")
        let row = rows[0]
        #expect(row.renderKind == "turn-activity")
        #expect(
            row.reasoningContent == "思考过程 R",
            "单条合成丢失思考内容，实际 \(String(describing: row.reasoningContent))"
        )
    }

    @Test("多条工具消息合成后按时间顺序保留全部 reasoningContent")
    func multiMemberToolGroupPreservesAllReasoningInOrder() {
        let conversationID = UUID()
        let turnID = UUID()
        let base = Date(timeIntervalSince1970: 1_000)
        let builder = MessageListRowBuilder()

        let first = makeToolOnlyMessage(
            id: UUID(), conversationID: conversationID, turnID: turnID,
            toolCallID: "c1", createdAt: base, reasoningContent: "R1"
        )
        let second = makeToolOnlyMessage(
            id: UUID(), conversationID: conversationID, turnID: turnID,
            toolCallID: "c2", createdAt: base.addingTimeInterval(1), reasoningContent: "R2"
        )

        let rows = builder.buildHistory(
            persisted: [first, second],
            conversationID: conversationID,
            verbosity: .standard
        )

        #expect(rows.count == 1, "相邻两条工具消息应合成 1 行")
        let row = rows[0]
        #expect(
            row.reasoningContent == "R1\n\nR2",
            "多条合成必须按时间顺序保留全部思考内容，实际 \(String(describing: row.reasoningContent))"
        )
    }

    @Test("无思考内容的普通工具消息合成后 reasoningContent 仍为 nil")
    func ordinaryToolGroupWithoutReasoningStaysNil() {
        let conversationID = UUID()
        let turnID = UUID()
        let base = Date(timeIntervalSince1970: 1_000)
        let builder = MessageListRowBuilder()

        let message = makeToolOnlyMessage(
            id: UUID(), conversationID: conversationID, turnID: turnID,
            toolCallID: "c1", createdAt: base, reasoningContent: nil
        )

        let rows = builder.buildHistory(
            persisted: [message],
            conversationID: conversationID,
            verbosity: .standard
        )

        #expect(rows.count == 1)
        #expect(
            rows[0].reasoningContent == nil,
            "普通工具消息不应引入思考内容，实际 \(String(describing: rows[0].reasoningContent))"
        )
    }
}
