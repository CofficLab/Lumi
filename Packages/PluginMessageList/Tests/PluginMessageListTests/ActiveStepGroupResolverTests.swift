import Testing
import Foundation
import ProviderConversation
import ProviderMessage
@testable import PluginMessageList

/// `ActiveStepGroupResolver` 的单元测试 —— V1「可折叠工具步骤组」的默认展开规则。
@Suite("ActiveStepGroupResolver")
struct ActiveStepGroupResolverTests {

    private let conversation = UUID()

    // MARK: - 基本 gate

    @Test("turn 未进行中 → 空集合(全部收起)")
    func emptyWhenTurnNotActive() {
        let rows = [assistantWithTools(id: UUID(), toolCallIDs: ["t1", "t2"])]
        let ids = ActiveStepGroupResolver.resolve(
            displayRows: rows, isTurnActive: false, verbosity: .brief
        )
        #expect(ids.isEmpty)
    }

    @Test("非 brief 模式 → 空集合(本特性仅 gate 在 brief)")
    func emptyWhenNotBrief() {
        let rows = [assistantWithTools(id: UUID(), toolCallIDs: ["t1"])]
        let ids = ActiveStepGroupResolver.resolve(
            displayRows: rows, isTurnActive: true, verbosity: .standard
        )
        #expect(ids.isEmpty)
    }

    @Test("turn 进行中也默认收起全部步骤组")
    func allToolGroupsAreCollapsedByDefault() {
        let id1 = UUID()
        let id2 = UUID()
        let rows = [
            assistantWithTools(id: id1, toolCallIDs: ["a"]),
            assistantWithTools(id: id2, toolCallIDs: ["b", "c"])
        ]
        let ids = ActiveStepGroupResolver.resolve(
            displayRows: rows, isTurnActive: true, verbosity: .brief
        )
        #expect(ids.isEmpty)
    }

    // MARK: - 多轮 / 边界

    @Test("历史和当前 turn 的步骤组都默认收起")
    func allStepGroupsAreCollapsedRegardlessOfTurnBoundary() {
        let oldGroup = UUID()
        let oldFinalReply = assistantFinalReply(id: UUID(), text: "已完成上一次任务")
        let currentGroup = UUID()

        let rows = [
            assistantWithTools(id: oldGroup, toolCallIDs: ["old1"]),
            oldFinalReply,
            assistantWithTools(id: currentGroup, toolCallIDs: ["new1", "new2"])
        ]
        let ids = ActiveStepGroupResolver.resolve(
            displayRows: rows, isTurnActive: true, verbosity: .brief
        )
        #expect(ids.isEmpty)
    }

    @Test("无工具调用的助手消息不算步骤组(被忽略)")
    func plainAssistantMessagesAreIgnored() {
        let plainId = UUID()
        let rows: [Message] = [
            .init(conversationID: conversation, role: .assistant, content: "你好"),
            .init(conversationID: conversation, role: .assistant, content: "请稍等"),
            .init(id: plainId, conversationID: conversation, role: .assistant, content: "...", toolCalls: [])
        ]
        let ids = ActiveStepGroupResolver.resolve(
            displayRows: rows, isTurnActive: true, verbosity: .brief
        )
        #expect(ids.isEmpty)
    }

    @Test("turn-completed 标记也算边界")
    func turnCompletedMarkerIsBoundary() {
        let beforeGroup = UUID()
        let afterGroup = UUID()
        let rows = [
            assistantWithTools(id: beforeGroup, toolCallIDs: ["x"]),
            .init(
                conversationID: conversation, role: .assistant,
                content: LumiChatMarkers.turnCompleted, renderKind: "turn-completed"
            ),
            assistantWithTools(id: afterGroup, toolCallIDs: ["y"])
        ]
        let ids = ActiveStepGroupResolver.resolve(
            displayRows: rows, isTurnActive: true, verbosity: .brief
        )
        #expect(ids.isEmpty)
    }

    // MARK: - isTurnBoundary

    @Test("isTurnBoundary:仅正文非空且无工具调用的助手消息构成边界")
    func turnBoundaryDetection() {
        // 助手最终回复 → 边界
        #expect(ActiveStepGroupResolver.isTurnBoundary(
            .init(conversationID: conversation, role: .assistant, content: "done")
        ))
        // 助手带工具调用 → 非边界(它是步骤组本身)
        #expect(!ActiveStepGroupResolver.isTurnBoundary(
            assistantWithTools(id: UUID(), toolCallIDs: ["t"])
        ))
        // 助手空正文 → 非边界
        #expect(!ActiveStepGroupResolver.isTurnBoundary(
            .init(conversationID: conversation, role: .assistant, content: "  ")
        ))
        // 用户消息 → 非边界
        #expect(!ActiveStepGroupResolver.isTurnBoundary(
            .init(conversationID: conversation, role: .user, content: "hi")
        ))
        // turn-completed 标记 → 边界
        #expect(ActiveStepGroupResolver.isTurnBoundary(
            .init(conversationID: conversation, role: .assistant,
                  content: LumiChatMarkers.turnCompleted)
        ))
    }

    // MARK: - Helpers

    /// 构造一条带 N 个工具调用、且结果为 nil（运行中）的助手消息。
    private func assistantWithTools(id: UUID, toolCallIDs: [String]) -> Message {
        let calls = toolCallIDs.map {
            MessageToolCall(id: $0, name: "tool_\($0)", arguments: "{}")
        }
        return .init(
            id: id, conversationID: conversation, role: .assistant,
            content: "...", toolCalls: calls
        )
    }

    /// 构造一条"上一轮最终自然语言回复"(边界消息)。
    private func assistantFinalReply(id: UUID, text: String) -> Message {
        .init(id: id, conversationID: conversation, role: .assistant, content: text)
    }
}
