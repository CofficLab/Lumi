import Foundation
import ProviderConversation
import ProviderConversationInput
import ProviderConversationInputBlock
import ProviderConversationState
import ProviderMessage
import ProviderMessageSender
import ProviderPerformanceMetrics
import Testing
@testable import PluginConversationInput

/// `ConversationInputObserver` 的事件路由与 capability adapter 的降级行为。
///
/// 两个套件放在一起，因为它们是同一段装配的两端：Observer 决定「哪些事件该写进
/// 输入框 ViewModel」，adapter 决定「Provider 缺失时这些事件从哪来」。
///
/// `ConversationInputObserver` 订阅的是**多路** Provider 事件（文本、折叠块、
/// 错误提示、附件），最容易出的错是**误路由**——比如把回合事件当成附件变化处理，
/// 或错误提示变了却没同步。前者造成无谓刷新，后者造成错误条不消失。
@MainActor
@Suite("ConversationInputObserver 事件路由")
struct ConversationInputObserverTests {

    @Test("文本变化触发整表刷新")
    func textChangeRefreshesViewModel() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)
        let observer = ConversationInputObserver(capability: capability, viewModel: viewModel)

        let revisionBefore = viewModel.revision
        capability.emitText("hello")

        #expect(viewModel.text == "hello")
        // 文本变化应走 refresh（整表重算），而不是只更新一个字段。
        #expect(viewModel.revision > revisionBefore)
        observer.cancel()
    }

    @Test("附件变化触发刷新，回合类事件被忽略")
    func attachmentEventRefreshesButTurnEventsAreIgnored() {
        let capability = SendActionBarTestCapability()
        capability.pendingImageAttachments = [
            UserImageAttachment(mimeType: "image/png", base64Data: "AAAA")
        ]
        let viewModel = ConversationInputViewModel(capability: capability)
        let observer = ConversationInputObserver(capability: capability, viewModel: viewModel)

        let revisionBefore = viewModel.revision
        capability.emitAttachmentsChanged()

        #expect(viewModel.imageAttachments.count == 1)
        #expect(viewModel.revision > revisionBefore)

        // 回合开始 / 结束不应驱动输入框刷新——那属于发送按钮的职责。
        // 若被误路由，每轮回复都会无谓地重建一次输入框状态。
        let revisionAfterAttachment = viewModel.revision
        capability.emitTurnStarted(conversationID: UUID())
        #expect(viewModel.revision == revisionAfterAttachment)

        capability.emitTurnCompleted(conversationID: UUID(), outcome: .completed)
        #expect(viewModel.revision == revisionAfterAttachment)
        observer.cancel()
    }

    @Test("错误提示变化同步到 ViewModel")
    func errorMessageChangeIsSynchronized() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)
        let observer = ConversationInputObserver(capability: capability, viewModel: viewModel)

        #expect(viewModel.errorMessage == nil)

        capability.emitErrorMessageChanged("send failed")

        #expect(viewModel.errorMessage == "send failed")
        observer.cancel()
    }

    @Test("折叠块递交后进入待插入状态")
    func blockSubmissionEnqueuesPendingBlock() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)
        let observer = ConversationInputObserver(capability: capability, viewModel: viewModel)

        #expect(viewModel.pendingBlock == nil)

        let block = ConversationInputBlock(
            text: String(repeating: "let x = 1\n", count: 100),
            title: "main.swift",
            systemImage: "chevron.left.forwardslash.chevron.right",
            collapseThreshold: 400
        )
        capability.emitBlockSubmitted(block)

        #expect(viewModel.pendingBlock?.id == block.id)
        #expect(viewModel.pendingBlock?.title == "main.swift")
        observer.cancel()
    }

    @Test("取消后所有事件都不再影响 ViewModel")
    func cancelStopsAllEventRouting() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)
        let observer = ConversationInputObserver(capability: capability, viewModel: viewModel)

        observer.cancel()

        capability.emitText("ignored")
        capability.emitErrorMessageChanged("ignored")
        capability.emitBlockSubmitted(
            ConversationInputBlock(
                text: "x",
                title: "t",
                systemImage: "s",
                collapseThreshold: 400
            )
        )

        #expect(viewModel.text.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.pendingBlock == nil)
    }
}

/// Provider 全部缺失时 adapter 必须给出安全默认值，而不是崩溃或抛错。
///
/// 这是「插件降级」这条链路的最后一环：`ConversationInputPlugin.onBoot` 在 Provider
/// 齐备时正常装配，缺失时整条输入链路应保持**可用但无能力**——用户仍能打字，
/// 只是发不出去（并由 Action Bar 上的错误按钮如实告知缺了谁）。
@MainActor
@Suite("ConversationInputCapabilityAdapter 降级")
struct ConversationInputCapabilityDegradationTests {

    private func makeDegradedAdapter() -> ConversationInputCapabilityAdapter {
        ConversationInputCapabilityAdapter(
            input: nil,
            sender: nil,
            conversations: nil,
            conversationState: nil,
            metrics: nil
        )
    }

    @Test("输入相关读操作回落到安全默认值")
    func inputReadsFallBackToDefaults() {
        let capability = makeDegradedAdapter()

        #expect(capability.text == "")
        #expect(capability.errorMessage == nil)
        #expect(!capability.isInputFocused)
        #expect(capability.inputCursorPosition == 0)
        #expect(!capability.isInputFocused)
        // 高度回落到编辑器的最小高度，而不是 0。
        #expect(capability.inputHeight == ChatInputEditorView.minHeight)
    }

    @Test("写入与清理在 Provider 缺失时不崩溃")
    func writesAreSafeWithoutProviders() {
        let capability = makeDegradedAdapter()

        capability.text = "draft"
        capability.isInputFocused = true
        capability.errorMessage = "boom"
        capability.inputHeight = 120
        capability.clearInput()
        capability.clearAttachments()

        // 读回仍是默认值，写入被安全丢弃。
        #expect(capability.text == "")
        #expect(capability.errorMessage == nil)
    }

    @Test("发送类操作在 Provider 缺失时返回 nil 而非抛错")
    func sendOperationsDegradeToNil() async throws {
        let capability = makeDegradedAdapter()

        let syncCommit = try capability.commitUserMessage(
            "hello",
            imageAttachments: [],
            fileAttachments: [],
            conversationID: nil
        )
        let asyncCommit = try await capability.commitUserMessageInBackground(
            "hello",
            imageAttachments: [],
            fileAttachments: [],
            conversationID: nil
        )

        #expect(syncCommit == nil)
        #expect(asyncCommit == nil)

        // 这两个必须是无害的 no-op。
        capability.cancelCurrentRequest()
        await capability.startTurn(
            for: MessageSendCommit(conversationID: UUID(), userMessageID: UUID())
        )
    }

    @Test("附件操作在 Provider 缺失时回落到空集合")
    func attachmentReadsFallBackToEmpty() {
        let capability = makeDegradedAdapter()

        #expect(capability.pendingImageAttachments.isEmpty)
        #expect(capability.pendingFileAttachments.isEmpty)

        // 增删都应静默丢弃。
        capability.addImageAttachment(
            UserImageAttachment(mimeType: "image/png", base64Data: "AAAA")
        )
        capability.addFileAttachment(
            UserFileAttachment(fileName: "a.txt", mimeType: "text/plain", textContent: "a")
        )
        capability.removeImageAttachment(id: UUID())
        capability.removeFileAttachment(id: UUID())

        #expect(capability.pendingImageAttachments.isEmpty)
        #expect(capability.pendingFileAttachments.isEmpty)
    }

    @Test("会话查询在 Provider 缺失时回落到 nil / false")
    func conversationQueriesFallBack() {
        let capability = makeDegradedAdapter()

        #expect(capability.selectedConversationID == nil)
        #expect(!capability.isSending(for: UUID()))
        #expect(!capability.isSending(for: nil))
    }

    @Test("指标能力缺失时 beginMetrics 返回 nil 且其余调用无副作用")
    func metricsDegradeGracefully() throws {
        let capability = makeDegradedAdapter()

        let trace = capability.beginMetrics(operation: "chat.send", metadata: [:])

        #expect(trace == nil)
        // trace 为 nil 时这两个调用不应当崩溃（发送路径无条件调用它们）。
        capability.endMetrics(try! #require(PerformanceTraceBox.make()))
        capability.markMetrics(try! #require(PerformanceTraceBox.make()), stage: "message.committed")
    }

    @Test("订阅在 Provider 缺失时返回可安全 cancel 的空句柄")
    func observersDegradeToNoopHandles() {
        let capability = makeDegradedAdapter()

        let textHandle = capability.addTextObserver { _ in }
        let blockHandle = capability.addBlockObserver { _ in }
        let inputHandle = capability.addInputObserver { _ in }
        let senderHandle = capability.addMessageSenderObserver { _ in }
        let conversationHandle = capability.addSelectedConversationObserver { _ in }
        let stateHandle = capability.addConversationStateObserver { _ in }

        // 空句柄必须存在（调用方无差别地持有并 cancel），
        // 且重复 cancel 不能崩溃。
        textHandle.cancel()
        textHandle.cancel()
        blockHandle.cancel()
        inputHandle.cancel()
        senderHandle.cancel()
        conversationHandle.cancel()
        stateHandle.cancel()
    }
}

/// 构造一个真实 `PerformanceTrace`，用于验证 adapter 的降级调用不崩溃。
///
/// `PerformanceTrace.init` 是 `internal`，测试无法直接构造，只能经由
/// `DefaultPerformanceMetricsProvider.begin` 取得。
private enum PerformanceTraceBox {
    @MainActor
    static func make() -> PerformanceTrace? {
        DefaultPerformanceMetricsProvider(directoryURL: nil).begin(operation: "test")
    }
}
