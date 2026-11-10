import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageListChatGPT

/// V5（ChatGPT）轮次投影器测试。
///
/// 基准是 V5 方案第 2.5 节：
/// - 一轮由「用户消息」开启，其后的助手正文、工作历史与状态行归属这一轮；
/// - 轮尾操作只挂在轮尾助手正文上，且整轮只出现一次；
/// - 流式尾行属于**独立**的一轮，不并入历史轮次。
@Suite("V5 轮次投影器")
struct ChatGPTTurnProjectorTests {

    private func user(_ content: String, id: UUID = UUID()) -> Message {
        Message(id: id, conversationID: UUID(), role: .user, content: content)
    }

    private func assistant(_ content: String, turnID: UUID? = nil) -> Message {
        Message(
            conversationID: UUID(),
            role: .assistant,
            content: content,
            turnID: turnID
        )
    }

    @Test("用户消息开启新轮次")
    func userMessageStartsNewTurn() {
        let turns = ChatGPTTurnProjector.project([
            user("问一"),
            assistant("答一"),
            user("问二"),
            assistant("答二"),
        ])

        #expect(turns.count == 2)
        #expect(turns[0].rows.count == 2)
        #expect(turns[1].rows.count == 2)
    }

    @Test("轮尾正文是最后一个助手正文行")
    func tailAssistantIsLastBodyRow() {
        let turns = ChatGPTTurnProjector.project([
            user("问"),
            assistant("答一"),
            assistant("答二"),
        ])

        #expect(turns.count == 1)
        #expect(turns[0].tailAssistantRowID != nil)
        #expect(turns[0].assistantCopyText == "答一\n\n答二")
    }

    @Test("整轮复制文本只含助手正文")
    func copyTextOnlyIncludesAssistantBody() {
        let turns = ChatGPTTurnProjector.project([
            user("用户提问"),
            assistant("助手回答"),
        ])

        #expect(turns[0].assistantCopyText == "助手回答")
    }

    @Test("工具执行消息不计入复制文本")
    func toolExecutionExcludedFromCopyText() {
        let toolOnly = Message(
            conversationID: UUID(),
            role: .assistant,
            content: "",
            toolCalls: [MessageToolCall(id: "c1", name: "explore", arguments: "{}")]
        )

        let turns = ChatGPTTurnProjector.project([
            user("问"),
            toolOnly,
            assistant("答"),
        ])

        #expect(turns[0].assistantCopyText == "答")
    }

    @Test("turnID 冲突开启新轮次")
    func turnIDConflictStartsNewTurn() {
        let turnA = UUID()
        let turnB = UUID()

        let turns = ChatGPTTurnProjector.project([
            assistant("甲", turnID: turnA),
            assistant("乙", turnID: turnB),
        ])

        #expect(turns.count == 2)
    }

    @Test("相同 turnID 的消息归入同一轮")
    func sameTurnIDStaysInOneTurn() {
        let turnID = UUID()

        let turns = ChatGPTTurnProjector.project([
            assistant("甲", turnID: turnID),
            assistant("乙", turnID: turnID),
        ])

        #expect(turns.count == 1)
        #expect(turns[0].rows.count == 2)
    }

    @Test("轮次身份是确定性的")
    func turnIdentityIsDeterministic() {
        let message = user("问")
        let first = ChatGPTTurnProjector.project([message])
        let second = ChatGPTTurnProjector.project([message])

        #expect(first.map(\.id) == second.map(\.id))
        #expect(first.first?.id == "message:\(message.id.uuidString)")
    }

    @Test("流式尾行是独立的一轮")
    func streamingTailIsIndependentTurn() {
        let streaming = Message(conversationID: UUID(), role: .assistant, content: "生成中")

        let projection = ChatGPTTurnProjector.project(
            history: [user("问"), assistant("答")],
            streaming: streaming,
            activity: nil
        )

        // 历史轮次 + 流式轮次。
        #expect(projection.turns.count == 2)
        #expect(projection.historyTurnCount == 1)
        #expect(projection.turns.last?.isRunning == true)
    }

    @Test("流式存在时不与活动行并存")
    func streamingSuppressesActivityRow() {
        let streaming = Message(conversationID: UUID(), role: .assistant, content: "生成中")
        let activity = Message(conversationID: UUID(), role: .status, content: "思考中")

        let projection = ChatGPTTurnProjector.project(
            history: [],
            streaming: streaming,
            activity: activity
        )

        #expect(projection.turns.count == 1)
        #expect(projection.turns[0].rows[0].origin == .streaming)
    }

    @Test("没有流式时使用活动行")
    func activityRowUsedWithoutStreaming() {
        let activity = Message(conversationID: UUID(), role: .status, content: "思考中")

        let projection = ChatGPTTurnProjector.project(
            history: [],
            streaming: nil,
            activity: activity
        )

        #expect(projection.turns.count == 1)
        #expect(projection.turns[0].rows[0].origin == .activity)
    }

    @Test("空输入不产生空轮次")
    func emptyInputProducesNoTurns() {
        #expect(ChatGPTTurnProjector.project([]).isEmpty)
    }
}
