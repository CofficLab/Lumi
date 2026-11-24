import Foundation
import KitMessageList
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageListBrief

/// #1187 共享投影上下文的回归测试。
///
/// 一次消息事件要投影多个 turn 行：原先每个 `AgentTurnVM` 独立读取完整
/// 快照并各自排序 / 分组全量会话（O(T × M log M)）。修复后父级每次事件
/// 只读取一份快照、构建一次 `AgentTurnSummaryContext`，全部可见行复用。
@MainActor
struct SharedProjectionContextTests {

    private let conversationID = UUID()

    // MARK: - §1 投影等价性

    @Test("build(records:messages:) 与 build(records:context:) 产出完全一致（回归 #1187）")
    func sharedContextBuildMatchesMessagesBuild() {
        let base = Date()
        let turn1 = UUID()
        let turn2 = UUID()
        let turn3 = UUID()

        // 已完成 turn：工具调用 + 工具结果 + 最终回复。
        let user1 = Message(conversationID: conversationID, role: .user, content: "第一问", createdAt: base)
        let call1 = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: base.addingTimeInterval(1),
            turnID: turn1,
            toolCalls: [MessageToolCall(id: "c1", name: "run", arguments: "{}", displayDescription: "执行")]
        )
        let tool1 = Message(conversationID: conversationID, role: .tool, content: "raw output", createdAt: base.addingTimeInterval(2), turnID: turn1)
        let final1 = Message(conversationID: conversationID, role: .assistant, content: "完成", createdAt: base.addingTimeInterval(3), turnID: turn1)

        // 运行中 turn：工具调用 + 结果 + 无 turnID 的瞬时 status。
        let user2 = Message(conversationID: conversationID, role: .user, content: "第二问", createdAt: base.addingTimeInterval(10))
        let call2 = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: base.addingTimeInterval(11),
            turnID: turn2,
            toolCalls: [MessageToolCall(id: "c2", name: "search", arguments: "{}", displayDescription: "搜索")]
        )
        let tool2 = Message(conversationID: conversationID, role: .tool, content: "raw search", createdAt: base.addingTimeInterval(12), turnID: turn2)
        let transient = Message(conversationID: conversationID, role: .status, content: "正在执行…", createdAt: base.addingTimeInterval(13))

        // 失败 turn：error 消息。
        let user3 = Message(conversationID: conversationID, role: .user, content: "第三问", createdAt: base.addingTimeInterval(20))
        let error3 = Message(conversationID: conversationID, role: .error, content: "运行失败", createdAt: base.addingTimeInterval(21), turnID: turn3)

        let records = [
            AgentTurnRecord(id: turn1, conversationID: conversationID, startedAt: base, endedAt: final1.createdAt, state: .completed),
            AgentTurnRecord(id: turn2, conversationID: conversationID, startedAt: base.addingTimeInterval(10), endedAt: nil, state: .running),
            AgentTurnRecord(id: turn3, conversationID: conversationID, startedAt: base.addingTimeInterval(20), endedAt: error3.createdAt, state: .failed)
        ]
        let all = [user1, call1, tool1, final1, user2, call2, tool2, transient, user3, error3]

        let fromMessages = AgentTurnSummaryBuilder().build(records: records, messages: all)
        let fromContext = AgentTurnSummaryBuilder().build(records: records, context: AgentTurnSummaryContext(all))

        #expect(fromMessages == fromContext)
        // 非空断言：保证等价不是「两边都空」的假阳性。
        #expect(fromMessages.count == 3)
        #expect(fromMessages[0].userMessage?.id == user1.id)
        #expect(fromMessages[0].message.id == final1.id)
        #expect(fromMessages[0].processMessages.contains { $0.id == call1.id })
        #expect(fromMessages[0].processMessages.contains { $0.id == tool1.id } == false)
        #expect(fromMessages[1].processMessages.contains { $0.id == transient.id })
        #expect(fromMessages[2].message.id == error3.id)

        // 乱序传入也一致：排序在上下文里完成，结果与输入顺序无关。
        let shuffled = [error3, user2, final1, tool1, call2, user1, transient, user3, tool2, call1]
        let fromShuffled = AgentTurnSummaryBuilder().build(records: records, messages: shuffled)
        let fromShuffledContext = AgentTurnSummaryBuilder()
            .build(records: records, context: AgentTurnSummaryContext(shuffled))
        #expect(fromShuffled == fromShuffledContext)
        #expect(fromShuffled == fromMessages)
    }

    @Test("AgentTurnVM.project 的 messages / context 两条入口产出一致（回归 #1187）")
    func turnVMProjectEntriesMatch() {
        let base = Date()
        let turnID = UUID()
        let user = Message(conversationID: conversationID, role: .user, content: "问", createdAt: base)
        let assistant = Message(conversationID: conversationID, role: .assistant, content: "", createdAt: base.addingTimeInterval(1), turnID: turnID, toolCalls: [
            MessageToolCall(id: "c1", name: "run", arguments: "{}", displayDescription: "执行")
        ])
        let tool = Message(conversationID: conversationID, role: .tool, content: "raw", createdAt: base.addingTimeInterval(2), turnID: turnID)
        let final = Message(conversationID: conversationID, role: .assistant, content: "完成", createdAt: base.addingTimeInterval(3), turnID: turnID)
        let record = AgentTurnRecord(id: turnID, conversationID: conversationID, startedAt: base, endedAt: final.createdAt, state: .completed)
        let all = [user, assistant, tool, final]

        let summary = AgentTurnSummaryBuilder().build(records: [record], messages: all).first!
        let item = AgentTurnPresentationItem(recorded: summary, acceptsLiveActivity: false)

        let fromMessages = AgentTurnVM.project(item: item, messages: all)
        let fromContext = AgentTurnVM.project(item: item, context: AgentTurnSummaryContext(all))

        #expect(fromMessages == fromContext)
        #expect(fromMessages.userMessages.map(\.id) == [user.id])
        #expect(fromMessages.lastMessage?.id == final.id)
        #expect(fromMessages.processMessages.contains { $0.id == assistant.id })
        #expect(fromMessages.processMessages.contains { $0.id == tool.id } == false)
    }

    // MARK: - §2 单快照扇出

    /// 记录 `messagesSnapshot` 调用次数的内存消息桩。
    private final class CountingMessages: MessageListMessageCapability {
        let snapshot: [Message]
        private(set) var snapshotCallCount = 0

        init(snapshot: [Message]) {
            self.snapshot = snapshot
        }

        private func messages(of conversationID: UUID) -> [Message] {
            snapshot
                .filter { $0.conversationID == conversationID }
                .sorted { lhs, rhs in
                    if lhs.createdAt == rhs.createdAt { return lhs.id.uuidString < rhs.id.uuidString }
                    return lhs.createdAt < rhs.createdAt
                }
        }

        func messagesSnapshot(in conversationID: UUID) async -> [Message] {
            snapshotCallCount += 1
            return messages(of: conversationID)
        }

        func messagePageAsync(
            for conversationID: UUID,
            limit: Int,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) async -> [Message] {
            let all = messages(of: conversationID)
            guard let beforeMessageID else { return Array(all.suffix(limit)) }
            guard let index = all.firstIndex(where: { $0.id == beforeMessageID }) else { return [] }
            return Array(all[max(0, index - limit)..<index])
        }

        func hasEarlierMessagesAsync(
            for conversationID: UUID,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) async -> Bool {
            let all = messages(of: conversationID)
            guard let beforeMessageID else { return all.count > 10 }
            guard let index = all.firstIndex(where: { $0.id == beforeMessageID }) else { return false }
            return index > 0
        }
    }

    private final class LocalStubConversations: MessageListConversationCapability {
        var selected: UUID?
        init(selected: UUID?) { self.selected = selected }
        var selectedConversationID: UUID? { selected }
        func verbosity(for conversationID: UUID?) -> ResponseVerbosity { .brief }
    }

    @Test("一次消息事件只读取一份快照，全部 Turn VM 复用共享投影（回归 #1187）")
    func singleSnapshotFetchPerMessageEvent() async {
        let base = Date()
        let turnIDs = (0..<3).map { _ in UUID() }
        var messages: [Message] = []
        for (index, turnID) in turnIDs.enumerated() {
            messages.append(Message(
                conversationID: conversationID,
                role: .user,
                content: "问 \(index)",
                createdAt: base.addingTimeInterval(Double(index) * 10)
            ))
            messages.append(Message(
                conversationID: conversationID,
                role: .assistant,
                content: "答 \(index)",
                createdAt: base.addingTimeInterval(Double(index) * 10 + 1),
                turnID: turnID
            ))
        }
        let stub = CountingMessages(snapshot: messages)
        let conversations = LocalStubConversations(selected: conversationID)
        let services = MessageListServices(
            conversations: conversations,
            developerMode: nil,
            messages: stub,
            rendering: nil,
            agentTurn: nil
        )
        let vm = ConversationMessageListVM(services: services, pageSize: 40)
        await vm.activateCurrentConversation()
        for item in vm.agentTurns { _ = vm.agentTurnVM(for: item) }
        #expect(vm.trackedAgentTurnVMCount == 3, "前置：三个 turn 行都持有缓存 VM")

        let before = stub.snapshotCallCount
        let inserted = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "答 2 更新",
            createdAt: base.addingTimeInterval(32),
            turnID: turnIDs[2]
        )
        vm.handleMessageChange(.inserted(inserted, conversationID: conversationID))
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(
            stub.snapshotCallCount - before == 1,
            "一次消息事件应只读取一份快照；旧实现 T 个缓存 VM 各自独立读取（T 份）"
        )
    }
}
