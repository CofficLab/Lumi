import Foundation
import ProviderConversation
import ProviderConversationState
import ProviderMessage
import Testing
@testable import PluginMessageListChatGPT

/// V5（ChatGPT）真实流式的行为与性能测试。
///
/// 基准是 V5 方案 Task 7 的要求：
/// - `start → appendThinking → appendContent → end` 只影响 live tail，
///   历史 rebuild 次数不随 token 增长；
/// - 16ms 窗口内多次 delta 合并为一次 UI 刷新；end 能及时 flush，不丢最后一段；
/// - 新会话激活后，旧 streaming task 不写回；
/// - 无 streaming Provider 时只显示真实 activity，不产生伪逐字文本。
@MainActor
@Suite("V5 真实流式")
struct ChatGPTStreamingTests {

    private func makeViewModel(
        conversationID: UUID,
        streaming: StubStreamingCapability,
        streamingDisplayEnabled: Bool = true,
        projectionStore: ChatGPTTurnProjectionStore = ChatGPTTurnProjectionStore()
    ) -> ChatGPTListViewModel {
        let services = makeStubServices(
            conversationID: conversationID,
            streaming: streaming
        )
        return ChatGPTListViewModel(
            services: services,
            projectionStore: projectionStore,
            streamingDisplayEnabled: streamingDisplayEnabled
        )
    }

    // MARK: - 只影响 live tail

    @Test("流式全过程不增加历史重建次数")
    func streamingDoesNotRebuildHistory() async {
        let conversationID = UUID()
        let streaming = StubStreamingCapability()
        let projectionStore = ChatGPTTurnProjectionStore()
        let viewModel = makeViewModel(
            conversationID: conversationID,
            streaming: streaming,
            projectionStore: projectionStore
        )

        await viewModel.activate(conversationID: conversationID)
        let baseline = projectionStore.historyRebuildCount

        streaming.start(conversationID: conversationID)
        viewModel.handleStreamingChange(.updated(conversationID))
        for _ in 0..<50 {
            streaming.appendContent("token", conversationID: conversationID)
            viewModel.handleStreamingChange(.updated(conversationID))
        }
        streaming.end(conversationID: conversationID)
        viewModel.handleStreamingChange(.updated(conversationID))

        // 历史重建次数不随 token 增长。
        #expect(projectionStore.historyRebuildCount == baseline)
    }

    @Test("流式内容进入 live tail 而不进入历史行")
    func streamingContentStaysInLiveTail() async {
        let conversationID = UUID()
        let streaming = StubStreamingCapability()
        let viewModel = makeViewModel(conversationID: conversationID, streaming: streaming)

        await viewModel.activate(conversationID: conversationID)

        streaming.start(conversationID: conversationID)
        streaming.appendContent("正在生成", conversationID: conversationID)
        viewModel.handleStreamingChange(.updated(conversationID))
        // 等待帧门禁落地。
        try? await Task.sleep(nanoseconds: 40_000_000)

        #expect(viewModel.streamingRow?.content == "正在生成")
        // 历史行不包含流式内容。
        #expect(!viewModel.historyRows.contains { $0.content == "正在生成" })
    }

    // MARK: - 帧合并

    @Test("16ms 窗口内多次 delta 合并为一次刷新")
    func multipleDeltasAreCoalesced() async {
        let conversationID = UUID()
        let streaming = StubStreamingCapability()
        let viewModel = makeViewModel(conversationID: conversationID, streaming: streaming)

        await viewModel.activate(conversationID: conversationID)

        streaming.start(conversationID: conversationID)
        streaming.appendContent("a", conversationID: conversationID)

        // 连续投递多次事件，但只推进一次帧门禁。
        for _ in 0..<20 {
            viewModel.handleStreamingChange(.updated(conversationID))
        }

        // 帧门禁尚未到期：流式行还没更新。
        #expect(viewModel.streamingRow == nil)

        try? await Task.sleep(nanoseconds: 60_000_000)

        // 到期后一次性刷新，且拿到的是**最新**内容。
        #expect(viewModel.streamingRow != nil)
        #expect(viewModel.streamingRow?.content == "a")
    }

    @Test("end 能及时 flush，流式行消失")
    func endFlushesAndClearsStreamingRow() async {
        let conversationID = UUID()
        let streaming = StubStreamingCapability()
        let viewModel = makeViewModel(conversationID: conversationID, streaming: streaming)

        await viewModel.activate(conversationID: conversationID)

        streaming.start(conversationID: conversationID)
        streaming.appendContent("最后一段", conversationID: conversationID)
        viewModel.handleStreamingChange(.updated(conversationID))
        try? await Task.sleep(nanoseconds: 40_000_000)
        #expect(viewModel.streamingRow != nil)

        streaming.end(conversationID: conversationID)
        viewModel.handleStreamingChange(.updated(conversationID))
        try? await Task.sleep(nanoseconds: 40_000_000)

        #expect(viewModel.streamingRow == nil)
    }

    // MARK: - 异步身份

    @Test("新会话激活后旧 streaming task 不写回")
    func staleStreamingTaskDoesNotWriteBack() async {
        let conversationA = UUID()
        let conversationB = UUID()

        let streaming = StubStreamingCapability()
        let conversations = StubConversationCapability(selectedConversationID: conversationA)
        let services = makeStubServices(
            conversationID: conversationA,
            conversations: conversations,
            streaming: streaming
        )
        let viewModel = ChatGPTListViewModel(
            services: services,
            streamingDisplayEnabled: true
        )

        await viewModel.activate(conversationID: conversationA)

        // 切到 B。
        conversations.selectedConversationID = conversationB
        await viewModel.activate(conversationID: conversationB)

        // A 的流式事件晚到。
        streaming.start(conversationID: conversationA)
        streaming.appendContent("A 的内容", conversationID: conversationA)
        viewModel.handleStreamingChange(.updated(conversationA))
        try? await Task.sleep(nanoseconds: 40_000_000)

        // 不得把 A 的流式行写进当前会话。
        #expect(viewModel.streamingRow == nil)
    }

    // MARK: - 降级

    @Test("无 streaming Provider 时只显示真实 activity")
    func withoutStreamingProviderOnlyShowsActivity() async {
        let conversationID = UUID()
        let conversationState = StubConversationStateCapability()
        conversationState.snapshot = ConversationStateSnapshot(
            conversationID: conversationID,
            activity: .thinking
        )

        let services = makeStubServices(
            conversationID: conversationID,
            conversationState: conversationState
        )
        let viewModel = ChatGPTListViewModel(
            services: services,
            streamingDisplayEnabled: true
        )

        await viewModel.activate(conversationID: conversationID)

        // 没有流式行，但有真实活动行。
        #expect(viewModel.streamingRow == nil)
        #expect(viewModel.activityMessage?.content == "Thinking…")
    }

    @Test("流式开关关闭时不产生逐字行")
    func streamingDisabledProducesNoStreamingRow() async {
        let conversationID = UUID()
        let streaming = StubStreamingCapability()
        let viewModel = makeViewModel(
            conversationID: conversationID,
            streaming: streaming,
            streamingDisplayEnabled: false
        )

        await viewModel.activate(conversationID: conversationID)

        streaming.start(conversationID: conversationID)
        streaming.appendContent("不该出现", conversationID: conversationID)
        viewModel.handleStreamingChange(.updated(conversationID))
        try? await Task.sleep(nanoseconds: 40_000_000)

        #expect(viewModel.streamingRow == nil)
    }
}
