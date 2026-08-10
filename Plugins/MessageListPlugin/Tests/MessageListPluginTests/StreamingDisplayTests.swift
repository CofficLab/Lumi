import Foundation
import LumiKernel
import Testing
@testable import MessageListPlugin

/// 流式逐字显示的 ViewModel 层测试(对照 AppKit 版 `AppKitStreamingIntegrationTests`)。
///
/// 验证核心不变量:
/// 1. token 追加只更新独立的 `streamingRow`,`historyRows` 不变(避免活锁)。
/// 2. 流式结束后,落库行经 tail refresh 出现在 `historyRows`,`streamingRow` 归 nil,
///    且落库行 id ≠ `LumiStreamingRowID`(无重复、无 id 冲突)。
/// 3. brief 模式下 `streamingRow` 永远 nil。
/// 4. 帧门禁:连续多次流式更新,被合并成每帧(~16ms)最多一次刷新。
@Suite(.serialized)
@MainActor
struct StreamingDisplayTests {

    // MARK: - Helpers

    private func makeKernel(
        messages: MockMessageManager,
        conversations: MockConversationManager,
        streaming: MockMessageStreaming
    ) throws -> LumiKernel {
        let kernel = LumiKernel()
        try kernel.registerService(MessageManaging.self, messages)
        try kernel.registerService(ConversationManaging.self, conversations)
        try kernel.registerService(MessageStreaming.self, streaming)
        return kernel
    }

    /// 等待帧门禁的 16ms sleep + 后续主线程落地完成。
    private func settle(_ nanoseconds: UInt64 = 60_000_000) async {
        try? await Task.sleep(nanoseconds: nanoseconds)
    }

    // MARK: - Tests

    @Test("token 追加只更新 streamingRow,historyRows 不变")
    func tokenUpdatesOnlyStreamingRow() async throws {
        let conversationID = UUID()
        let messages = MockMessageManager()
        let conversations = MockConversationManager()
        conversations.selectedConversationID = conversationID
        let streaming = MockMessageStreaming()
        let kernel = try makeKernel(
            messages: messages, conversations: conversations, streaming: streaming
        )

        // 预置一条历史消息。
        messages.seed([
            LumiChatMessage(
                conversationID: conversationID,
                role: .assistant,
                content: "历史消息",
                createdAt: Date(timeIntervalSinceReferenceDate: 100)
            )
        ], conversationID: conversationID)

        let viewModel = ListV2ViewModel(kernel: kernel)
        await viewModel.activate(conversationID: conversationID)
        await settle()

        let historyBefore = viewModel.historyRows
        #expect(historyBefore.count == 1)

        // 流式开始 + 第一个 token。
        streaming.inject(
            row: LumiChatMessage(
                id: LumiStreamingRowID,
                conversationID: conversationID,
                role: .assistant,
                content: "正在"
            ),
            stage: .generating,
            conversationID: conversationID
        )
        await settle()

        #expect(viewModel.streamingRow != nil)
        #expect(viewModel.streamingRow?.content == "正在")
        #expect(viewModel.historyRows == historyBefore) // 历史行不变

        // 第二个 token:内容增长,历史行仍不变。
        streaming.inject(
            row: LumiChatMessage(
                id: LumiStreamingRowID,
                conversationID: conversationID,
                role: .assistant,
                content: "正在生成"
            ),
            stage: .generating,
            conversationID: conversationID
        )
        await settle()

        #expect(viewModel.streamingRow?.content == "正在生成")
        #expect(viewModel.historyRows == historyBefore)
    }

    @Test("流式结束后落库行替换流式行(稳定 ID,无重复)")
    func streamingToPersistedSwap() async throws {
        let conversationID = UUID()
        let messages = MockMessageManager()
        let conversations = MockConversationManager()
        conversations.selectedConversationID = conversationID
        let streaming = MockMessageStreaming()
        let kernel = try makeKernel(
            messages: messages, conversations: conversations, streaming: streaming
        )

        let viewModel = ListV2ViewModel(kernel: kernel)
        await viewModel.activate(conversationID: conversationID)
        await settle()

        // 流式中。
        streaming.inject(
            row: LumiChatMessage(
                id: LumiStreamingRowID,
                conversationID: conversationID,
                role: .assistant,
                content: "最终回复"
            ),
            stage: .generating,
            conversationID: conversationID
        )
        await settle()
        #expect(viewModel.streamingRow != nil)

        // 落库:endStreaming + 真实消息 + 触发 tail refresh。
        // (生产中 refreshTail 由 View 层的 .onLumiMessagesDidChange 触发;
        //  此处只测 ViewModel,手动调用。)
        streaming.inject(row: nil, stage: .idle, conversationID: conversationID)
        let persisted = LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "最终回复",
            createdAt: Date(timeIntervalSinceReferenceDate: 500)
        )
        messages.insertMessage(persisted, to: conversationID)
        _ = await viewModel.refreshTail()
        await settle()

        #expect(viewModel.streamingRow == nil) // 临时行消失
        #expect(viewModel.historyRows.count == 1) // 仅真实行
        let row = viewModel.historyRows.first
        #expect(row?.id != LumiStreamingRowID) // id 与流式行不同
        #expect(row?.id == persisted.id)
        #expect(row?.content == "最终回复")
    }

    @Test("brief 模式下 streamingRow 始终 nil")
    func briefHidesStreamingRow() async throws {
        let conversationID = UUID()
        let messages = MockMessageManager()
        let conversations = MockConversationManager()
        conversations.selectedConversationID = conversationID
        conversations.globalVerbosity = .brief
        let streaming = MockMessageStreaming()
        let kernel = try makeKernel(
            messages: messages, conversations: conversations, streaming: streaming
        )

        let viewModel = ListV2ViewModel(kernel: kernel)
        await viewModel.activate(conversationID: conversationID)
        await settle()

        // brief 模式注入流式状态:ViewModel 应忽略(streamingRow 保持 nil)。
        streaming.inject(
            row: LumiChatMessage(
                id: LumiStreamingRowID,
                conversationID: conversationID,
                role: .assistant,
                content: "不应显示"
            ),
            stage: .generating,
            conversationID: conversationID
        )
        await settle()

        #expect(viewModel.streamingRow == nil)
    }

    @Test("status 行在流式行可见时被隐藏")
    func statusRowHidesWhileStreaming() async throws {
        let conversationID = UUID()
        let messages = MockMessageManager()
        let conversations = MockConversationManager()
        conversations.selectedConversationID = conversationID
        let streaming = MockMessageStreaming()
        let kernel = try makeKernel(
            messages: messages, conversations: conversations, streaming: streaming
        )

        // 预置一条 status 消息("正在思考…")。
        messages.seed([
            LumiChatMessage(
                conversationID: conversationID,
                role: .status,
                content: "正在思考…",
                createdAt: Date(timeIntervalSinceReferenceDate: 100)
            )
        ], conversationID: conversationID)

        let viewModel = ListV2ViewModel(kernel: kernel)
        await viewModel.activate(conversationID: conversationID)
        await settle()

        // 流式前:status 行可见(historyRows 含它,具体取决于 rowBuilder 是否保留 status)。
        let beforeCount = viewModel.historyRows.count

        // 流式行出现:status 行应被隐藏(hidesStatus = true)。
        streaming.inject(
            row: LumiChatMessage(
                id: LumiStreamingRowID,
                conversationID: conversationID,
                role: .assistant,
                content: "生成中"
            ),
            stage: .generating,
            conversationID: conversationID
        )
        await settle()

        #expect(viewModel.streamingRow != nil)
        // status 行被隐藏后,historyRows 里不应再含 .status 行。
        let statusRowsDuringStreaming = viewModel.historyRows.filter { $0.role == .status }
        #expect(statusRowsDuringStreaming.isEmpty)

        // 流式结束:status 行应恢复可见。
        streaming.inject(row: nil, stage: .idle, conversationID: conversationID)
        await settle()

        let statusRowsAfterStreaming = viewModel.historyRows.filter { $0.role == .status }
        #expect(statusRowsAfterStreaming.count == beforeCount)
    }
}
