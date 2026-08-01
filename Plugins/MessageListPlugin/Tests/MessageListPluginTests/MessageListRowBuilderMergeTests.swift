import Testing
import Foundation
import LumiKernel
@testable import MessageListPlugin

/// `MessageListRowBuilder` 工具消息合并逻辑的单元测试。
///
/// 验证数据层把连续多条「只含工具调用的助手消息」合并成一条合成消息
/// (`renderKind == "tool-step-group"`),V1 与 V2/V3 都生效。
@MainActor
@Suite("MessageListRowBuilder tool-step-group merging")
struct MessageListRowBuilderMergeTests {

    private let conversation = UUID()
    private let builder = MessageListRowBuilder()

    // MARK: - 合并

    @Test("V1:连续多条工具执行消息合并成一条合成消息")
    func v1MergesConsecutiveToolMessages() throws {
        let m1 = toolExec(id: UUID(), calls: ["a"])
        let m2 = toolExec(id: UUID(), calls: ["b"])
        let m3 = toolExec(id: UUID(), calls: ["c"])
        let rows = builder.build(
            persisted: [m1, m2, m3],
            conversationID: conversation,
            streaming: nil,
            verbosity: .brief
        )
        // 合并成 1 条。
        #expect(rows.count == 1)
        let merged = try #require(rows.first)
        #expect(merged.renderKind == "tool-step-group")
        // 平铺所有工具调用。
        #expect(merged.toolCalls?.map(\.id) == ["a", "b", "c"])
        // 复用首条消息的 id(稳定)。
        #expect(merged.id == m1.id)
    }

    @Test("V1:遇到非工具执行消息即断组,产生多个合成消息")
    func v1BreaksGroupAtNonToolMessage() {
        let g1a = toolExec(id: UUID(), calls: ["a"])
        let g1b = toolExec(id: UUID(), calls: ["b"])
        let reply = LumiChatMessage(conversationID: conversation, role: .assistant, content: "done")
        let g2a = toolExec(id: UUID(), calls: ["c"])
        let rows = builder.build(
            persisted: [g1a, g1b, reply, g2a],
            conversationID: conversation,
            streaming: nil,
            verbosity: .brief
        )
        // [group(a,b), reply, group(c)]
        #expect(rows.count == 3)
        #expect(rows[0].renderKind == "tool-step-group")
        #expect(rows[0].toolCalls?.map(\.id) == ["a", "b"])
        #expect(rows[1].content == "done")
        #expect(rows[2].renderKind == "tool-step-group")
        #expect(rows[2].toolCalls?.map(\.id) == ["c"])
    }

    @Test("V1:单条工具执行消息也走合成路径(向后兼容)")
    func v1SingleToolMessageBecomesGroup() {
        let m = toolExec(id: UUID(), calls: ["only"])
        let rows = builder.build(
            persisted: [m],
            conversationID: conversation,
            streaming: nil,
            verbosity: .brief
        )
        #expect(rows.count == 1)
        #expect(rows[0].renderKind == "tool-step-group")
        #expect(rows[0].toolCalls?.map(\.id) == ["only"])
    }

    @Test("V2/V3 也合并(多个工具卡片聚在一个气泡)")
    func v2AlsoMerges() throws {
        let m1 = toolExec(id: UUID(), calls: ["a"])
        let m2 = toolExec(id: UUID(), calls: ["b"])
        let rows = builder.build(
            persisted: [m1, m2],
            conversationID: conversation,
            streaming: nil,
            verbosity: .standard
        )
        #expect(rows.count == 1)
        let merged = try #require(rows.first)
        #expect(merged.renderKind == "tool-step-group")
        #expect(merged.toolCalls?.map(\.id) == ["a", "b"])
    }

    @Test("V1:剔除独立 .tool 结果行")
    func v1DropsToolResultRows() {
        let assistant = toolExec(id: UUID(), calls: ["a"])
        let toolResult = LumiChatMessage(
            conversationID: conversation, role: .tool, content: "result", toolCallID: "a"
        )
        let rows = builder.build(
            persisted: [assistant, toolResult],
            conversationID: conversation,
            streaming: nil,
            verbosity: .brief
        )
        // .tool 行被过滤,只剩合成消息。
        #expect(rows.count == 1)
        #expect(rows[0].renderKind == "tool-step-group")
    }

    @Test("conversationID 为 nil 时不合并(原样返回)")
    func noMergeWithoutConversation() {
        let m1 = toolExec(id: UUID(), calls: ["a"])
        let m2 = toolExec(id: UUID(), calls: ["b"])
        let rows = builder.build(
            persisted: [m1, m2],
            conversationID: nil,
            streaming: nil,
            verbosity: .brief
        )
        // guard early-return:原样返回,不合并。
        #expect(rows.count == 2)
        #expect(rows.allSatisfy { $0.renderKind != "tool-step-group" })
    }

    // MARK: - Helper

    /// 构造一条 `isToolExecutionOnly` 的助手消息(content = "...",带工具调用)。
    private func toolExec(id: UUID, calls: [String]) -> LumiChatMessage {
        let toolCalls = calls.map { LumiToolCall(id: $0, name: "tool_\($0)", arguments: "{}") }
        return LumiChatMessage(
            id: id, conversationID: conversation, role: .assistant,
            content: "...", toolCalls: toolCalls
        )
    }
}
