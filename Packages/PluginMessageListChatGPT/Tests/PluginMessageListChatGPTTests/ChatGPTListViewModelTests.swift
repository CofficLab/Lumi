import Foundation
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageListChatGPT

/// V5（ChatGPT）消息窗口与异步身份的视图模型测试。
///
/// 基准是 V5 方案 Task 5 的五类要求：
/// 1. 旧请求晚到：A 的快照被闸门挂住，激活 B 并完成后再释放 A；最终只能显示 B。
/// 2. 分页有界：pageSize 40、retained 300。
/// 3. 工具分组：不跨普通正文合并 tool-only assistant；合成 ID 随成员变化。
/// 4. projection 失效：100 行历史 + 50 次流式快照，history rebuild 为 1。
/// 5. 删除/清空/切换：清空不残留旧行，切换会话重置 projection 与分页身份。
///
/// - Important: 异步测试使用**闸门**（gate）而非任意 `sleep` 猜时序。
@MainActor
@Suite("V5 消息窗口与异步身份")
struct ChatGPTListViewModelTests {

    // MARK: - 1. 旧请求晚到

    @Test("旧会话的迟到快照不会覆盖新会话")
    func staleSnapshotDoesNotOverwriteNewConversation() async {
        let conversationA = UUID()
        let conversationB = UUID()

        let messages = StubMessageCapability()
        let gate = AsyncGate()
        messages.gate = gate

        let userA = makeStubMessage(conversationID: conversationA, role: .user, content: "A")
        let userB = makeStubMessage(conversationID: conversationB, role: .user, content: "B")
        messages.messages = [userA, userB]

        let conversations = StubConversationCapability(selectedConversationID: conversationA)
        let services = makeStubServices(
            conversationID: conversationA,
            messages: messages,
            conversations: conversations
        )
        let viewModel = ChatGPTListViewModel(services: services)

        // A 的首屏挂在闸门上。
        let activateA = Task { await viewModel.activate(conversationID: conversationA) }

        // 切到 B 并让它完成。
        conversations.selectedConversationID = conversationB
        messages.gate = nil
        await viewModel.activate(conversationID: conversationB)

        #expect(viewModel.persistedMessages.map(\.content) == ["B"])

        // 现在释放 A 的迟到结果。
        await gate.open()
        await activateA.value

        // 最终仍然只能显示 B。
        #expect(viewModel.persistedMessages.map(\.content) == ["B"])
    }

    @Test("旧会话的迟到错误不会写入新会话状态")
    func staleErrorDoesNotWriteNewConversationState() async {
        let conversationA = UUID()
        let conversationB = UUID()

        let messages = StubMessageCapability()
        let gate = AsyncGate()
        messages.gate = gate
        messages.messages = [
            makeStubMessage(conversationID: conversationA, role: .user, content: "A"),
            makeStubMessage(conversationID: conversationB, role: .user, content: "B"),
        ]

        let conversations = StubConversationCapability(selectedConversationID: conversationA)
        let services = makeStubServices(
            conversationID: conversationA,
            messages: messages,
            conversations: conversations
        )
        let viewModel = ChatGPTListViewModel(services: services)

        let activateA = Task { await viewModel.activate(conversationID: conversationA) }

        conversations.selectedConversationID = conversationB
        messages.gate = nil
        await viewModel.activate(conversationID: conversationB)

        await gate.open()
        await activateA.value

        // 迟到的 A 不得让 B 的窗口变脏，也不得把 B 的 loading 状态改回去。
        #expect(viewModel.persistedMessages.allSatisfy { $0.conversationID == conversationB })
        #expect(!viewModel.isLoading)
    }

    @Test("会话切换重置窗口、分页与投影身份")
    func conversationSwitchResetsWindowAndProjection() async {
        let conversationA = UUID()
        let conversationB = UUID()

        let messages = StubMessageCapability()
        messages.messages = [
            makeStubMessage(conversationID: conversationA, role: .user, content: "A1"),
            makeStubMessage(conversationID: conversationA, role: .assistant, content: "A2"),
            makeStubMessage(conversationID: conversationB, role: .user, content: "B1"),
        ]

        let conversations = StubConversationCapability(selectedConversationID: conversationA)
        let services = makeStubServices(
            conversationID: conversationA,
            messages: messages,
            conversations: conversations
        )
        let viewModel = ChatGPTListViewModel(services: services)

        await viewModel.activate(conversationID: conversationA)
        #expect(viewModel.persistedMessages.count == 2)

        conversations.selectedConversationID = conversationB
        await viewModel.activate(conversationID: conversationB)

        // 旧会话的消息不得残留。
        #expect(viewModel.persistedMessages.allSatisfy { $0.conversationID == conversationB })
        #expect(viewModel.turnProjection.turns.allSatisfy {
            $0.rows.allSatisfy { $0.message.conversationID == conversationB }
        })
    }

    // MARK: - 2. 分页有界

    @Test("分页服务使用 pageSize 40 与 retained 300")
    func paginationBounds() {
        let service = MessageListPaginationService()
        #expect(service.pageSize == 40)
        #expect(service.maxRetainedCount == 300)
    }

    @Test("窗口回收后长度不超过上限")
    func evictionKeepsWindowBounded() {
        let service = MessageListPaginationService(pageSize: 40, maxRetainedCount: 300)
        let messages = (0..<500).map { index in
            makeStubMessage(
                conversationID: UUID(),
                role: .user,
                content: "\(index)",
                createdAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }

        let evicted = service.evictTailIfNeeded(messages: messages)
        #expect(evicted.count == 300)
        // 保留的是**较新**的一段（尾部）。
        #expect(evicted.last?.content == "499")
    }

    @Test("窗口未超限时不被裁剪")
    func evictionKeepsShortWindow() {
        let service = MessageListPaginationService(pageSize: 40, maxRetainedCount: 300)
        let messages = (0..<10).map {
            makeStubMessage(conversationID: UUID(), role: .user, content: "\($0)")
        }
        #expect(service.evictTailIfNeeded(messages: messages).count == 10)
    }

    @Test("首屏加载探测是否还有更早消息")
    func firstPageDetectsEarlierMessages() async {
        let conversationID = UUID()
        let messages = StubMessageCapability()
        messages.messages = (0..<60).map { index in
            makeStubMessage(
                conversationID: conversationID,
                role: .user,
                content: "\(index)",
                createdAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }

        let service = MessageListPaginationService()
        let result = await service.loadFirstPage(
            conversationID: conversationID,
            messageManager: messages
        )

        #expect(result.messages.count == 40)
        #expect(result.hasEarlierMessages)
    }

    // MARK: - 3. 工具分组

    @Test("工具组合并不跨普通正文")
    func toolGroupDoesNotCrossPlainBody() {
        let conversationID = UUID()
        let builder = MessageListRowBuilder()

        let toolOnly = makeStubMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: Date(timeIntervalSince1970: 1),
            toolCalls: [
                MessageToolCall(id: "c1", name: "explore", arguments: "{}"),
            ]
        )
        let body = makeStubMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "正文",
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let toolOnly2 = makeStubMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: Date(timeIntervalSince1970: 3),
            toolCalls: [
                MessageToolCall(id: "c2", name: "execute", arguments: "{}"),
            ]
        )

        let rows = builder.buildHistory(
            persisted: [toolOnly, body, toolOnly2],
            conversationID: conversationID,
            verbosity: .chatGPT
        )

        // 三行：工具组、正文、工具组 —— 工具组没有跨过正文合并。
        #expect(rows.count == 3)
        // 没有 turnID 的历史工具消息使用 "tool-step-group"（V4 的既有约定）。
        #expect(rows[0].renderKind == "tool-step-group")
        #expect(rows[1].content == "正文")
        #expect(rows[2].renderKind == "tool-step-group")
    }

    @Test("合成 ID 随组内成员变化")
    func synthesizedIDChangesWithMembers() {
        let conversationID = UUID()
        let builder = MessageListRowBuilder()

        let first = makeStubMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: Date(timeIntervalSince1970: 1),
            toolCalls: [MessageToolCall(id: "c1", name: "explore", arguments: "{}")]
        )
        let second = makeStubMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: Date(timeIntervalSince1970: 2),
            toolCalls: [MessageToolCall(id: "c2", name: "explore", arguments: "{}")]
        )

        let oneRow = builder.buildHistory(
            persisted: [first],
            conversationID: conversationID,
            verbosity: .chatGPT
        )
        let twoRows = builder.buildHistory(
            persisted: [first, second],
            conversationID: conversationID,
            verbosity: .chatGPT
        )

        // 成员集合变化 → 合成行 id 必须变化，
        // 否则 SwiftUI 认为这行「没变」而不重新物化，新并入的挂起工具行画不出来。
        #expect(oneRow[0].id != twoRows[0].id)
    }

    @Test("独立 tool 结果行不进入展示窗口")
    func standaloneToolRowsAreFiltered() {
        let conversationID = UUID()
        let builder = MessageListRowBuilder()

        let user = makeStubMessage(conversationID: conversationID, role: .user, content: "问")
        let toolResult = makeStubMessage(conversationID: conversationID, role: .tool, content: "结果")

        let rows = builder.buildHistory(
            persisted: [user, toolResult],
            conversationID: conversationID,
            verbosity: .chatGPT
        )

        #expect(rows.count == 1)
        #expect(rows[0].role == .user)
    }

    // MARK: - 4. projection 失效

    @Test("流式更新不触发历史 O(n) 重建")
    func streamingDoesNotRebuildHistory() {
        let store = ChatGPTTurnProjectionStore()
        let history = (0..<100).map { index in
            makeStubMessage(
                conversationID: UUID(),
                role: .user,
                content: "第 \(index) 条"
            )
        }

        _ = store.snapshot(history: history, streaming: nil, activity: nil)
        #expect(store.historyRebuildCount == 1)

        // 50 次流式快照：历史没有变，不应重建。
        for _ in 0..<50 {
            let streaming = makeStubMessage(conversationID: UUID(), role: .assistant, content: "生成中")
            _ = store.snapshot(history: history, streaming: streaming, activity: nil)
        }
        #expect(store.historyRebuildCount == 1)
    }

    @Test("等长正文替换会失效投影并更新复制文本")
    func equalLengthReplacementInvalidatesProjection() {
        let store = ChatGPTTurnProjectionStore()
        let conversationID = UUID()

        let first = makeStubMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "AAAA"
        )
        var projection = store.snapshot(history: [first], streaming: nil, activity: nil)
        #expect(projection.turns.first?.assistantCopyText == "AAAA")

        // 等长替换：长度不变，但内容变了。
        let second = makeStubMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "BBBB"
        )
        projection = store.snapshot(history: [second], streaming: nil, activity: nil)

        #expect(store.historyRebuildCount == 2)
        #expect(projection.turns.first?.assistantCopyText == "BBBB")
    }

    // MARK: - 5. 删除/清空

    @Test("清空会话后不残留旧行")
    func clearedConversationDropsOldRows() async {
        let conversationID = UUID()
        let messages = StubMessageCapability()
        messages.messages = [
            makeStubMessage(conversationID: conversationID, role: .user, content: "旧消息"),
        ]

        let services = makeStubServices(conversationID: conversationID, messages: messages)
        let viewModel = ChatGPTListViewModel(services: services)
        await viewModel.activate(conversationID: conversationID)
        #expect(viewModel.historyRows.count == 1)

        // 存储层被清空，并派发 `.cleared` 事件（真实路径）。
        messages.messages = []
        viewModel.handleMessageChange(.cleared(conversationID: conversationID))

        #expect(viewModel.historyRows.isEmpty)
        #expect(viewModel.persistedMessages.isEmpty)
    }

    @Test("存储被清空后尾部刷新也会清空窗口")
    func tailRefreshOnEmptyStorageClearsWindow() async {
        let conversationID = UUID()
        let messages = StubMessageCapability()
        messages.messages = [
            makeStubMessage(conversationID: conversationID, role: .user, content: "旧消息"),
        ]

        let services = makeStubServices(conversationID: conversationID, messages: messages)
        let viewModel = ChatGPTListViewModel(services: services)
        await viewModel.activate(conversationID: conversationID)
        #expect(viewModel.persistedMessages.count == 1)

        // 存储层被清空，但没有派发 `.cleared` 事件（例如清空发生在别处）。
        messages.messages = []
        await viewModel.refreshTail()

        // 存储已空却仍留着旧行，是数据不一致 —— 必须清掉。
        #expect(viewModel.persistedMessages.isEmpty)
    }

    @Test("插入用户消息后记录其 id，供 View 贴底")
    func insertedUserMessageIsTracked() async {
        let conversationID = UUID()
        let messages = StubMessageCapability()
        let services = makeStubServices(conversationID: conversationID, messages: messages)
        let viewModel = ChatGPTListViewModel(services: services)
        await viewModel.activate(conversationID: conversationID)

        let userMessage = makeStubMessage(conversationID: conversationID, role: .user, content: "新消息")
        viewModel.handleMessageChange(.inserted(userMessage, conversationID: conversationID))

        #expect(viewModel.latestUserMessageID == userMessage.id)
        #expect(viewModel.persistedMessages.contains { $0.id == userMessage.id })
    }

    @Test("isLoading 与 isLoadingEarlier 分离")
    func loadingFlagsAreIndependent() async {
        let conversationID = UUID()
        let messages = StubMessageCapability()
        messages.messages = (0..<100).map { index in
            makeStubMessage(
                conversationID: conversationID,
                role: .user,
                content: "\(index)",
                createdAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }

        let services = makeStubServices(conversationID: conversationID, messages: messages)
        let viewModel = ChatGPTListViewModel(services: services)
        await viewModel.activate(conversationID: conversationID)

        #expect(!viewModel.isLoading)
        #expect(!viewModel.isLoadingEarlier)
        #expect(viewModel.hasEarlierMessages)
    }
}
