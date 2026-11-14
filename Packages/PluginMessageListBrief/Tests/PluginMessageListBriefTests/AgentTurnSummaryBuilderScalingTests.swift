import Foundation
import ProviderAgentLoop
import ProviderMessage
import Testing
@testable import PluginMessageListBrief

/// Brief/V1 的 turn 投影的规模复杂度（见 issue #1267）。
///
/// 原先每次插入都对全量消息流做两轮线性扫描：
/// - 每个 record 过滤一次「瞬时 status」；
/// - 每个 record 从尾部反向扫描找最近的用户消息。
///
/// N 个 record 就是 N 次全量扫描，整体 O(N²)。修复后改为：
/// - 瞬时 status 按会话提前分好组；
/// - 用户消息抽成有序索引后二分查找。
struct AgentTurnSummaryBuilderScalingTests {

    private let conversationID = UUID()

    private func makeUser(_ content: String, at date: Date) -> Message {
        Message(
            conversationID: conversationID,
            role: .user,
            content: content,
            createdAt: date
        )
    }

    private func makeRecord(id: UUID, startedAt: Date, state: AgentLoopState = .completed) -> AgentTurnRecord {
        AgentTurnRecord(
            id: id,
            conversationID: conversationID,
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(1),
            state: state
        )
    }

    /// 用户消息回溯匹配的参照实现：逐条反向线性扫描。
    private func referenceUserMessage(before messages: [Message], startedAt: Date) -> Message? {
        for message in messages.reversed() where message.role == .user {
            if message.createdAt <= startedAt {
                return message
            }
        }
        return nil
    }

    @Test("每个 turn 都关联到正确的用户消息")
    func eachTurnMatchesItsUserMessage() {
        let base = Date()
        var messages: [Message] = []
        var records: [AgentTurnRecord] = []

        for index in 0..<20 {
            let userDate = base.addingTimeInterval(Double(index) * 10)
            let user = makeUser("user-\(index)", at: userDate)
            messages.append(user)

            let turnID = UUID()
            let assistant = Message(
                conversationID: conversationID,
                role: .assistant,
                content: "reply-\(index)",
                createdAt: userDate.addingTimeInterval(1),
                turnID: turnID
            )
            messages.append(assistant)

            records.append(
                makeRecord(
                    id: turnID,
                    startedAt: userDate.addingTimeInterval(0.5),
                    state: .completed
                )
            )
        }

        let items = AgentTurnSummaryBuilder().build(records: records, messages: messages)

        #expect(items.count == 20)
        for (index, item) in items.enumerated() {
            let expected = referenceUserMessage(
                before: messages.sorted { $0.createdAt < $1.createdAt },
                startedAt: records[index].startedAt
            )
            #expect(item.userMessage?.id == expected?.id, "turn \(index)")
        }
    }

    @Test("用户消息与 turn 同时刻时仍然匹配")
    func userMessageAtSameTimestampStillMatches() {
        let timestamp = Date()
        let user = makeUser("same", at: timestamp)
        let turnID = UUID()
        let record = makeRecord(id: turnID, startedAt: timestamp, state: .completed)

        let items = AgentTurnSummaryBuilder().build(records: [record], messages: [user])

        #expect(items.first?.userMessage?.id == user.id)
    }

    @Test("turn 之前没有用户消息时关联为空")
    func noUserMessageBeforeTurn() {
        let base = Date()
        let user = makeUser("later", at: base.addingTimeInterval(100))
        let turnID = UUID()
        let record = makeRecord(id: turnID, startedAt: base, state: .completed)

        let items = AgentTurnSummaryBuilder().build(records: [record], messages: [user])

        #expect(items.first?.userMessage == nil)
    }

    @Test("瞬时 status 只挂到最新活跃 turn")
    func transientStatusesOnlyOnLatestActiveTurn() {
        let base = Date()
        let firstID = UUID()
        let secondID = UUID()

        let status = Message(
            conversationID: conversationID,
            role: .status,
            content: "working",
            createdAt: base.addingTimeInterval(0.2)
        )

        let records = [
            makeRecord(id: firstID, startedAt: base, state: .running),
            makeRecord(id: secondID, startedAt: base.addingTimeInterval(10), state: .running),
        ]

        let items = AgentTurnSummaryBuilder().build(records: records, messages: [status])

        // 只有一个 turn 能拿到瞬时 status。
        let withStatus = items.filter { !$0.processMessages.isEmpty }
        #expect(withStatus.count == 1)
    }
}
