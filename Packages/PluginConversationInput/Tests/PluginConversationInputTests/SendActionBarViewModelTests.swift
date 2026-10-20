import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderConversationInput
import ProviderConversationInputBlock
import ProviderConversationState
import ProviderMessage
import ProviderMessageSender
import ProviderPerformanceMetrics
import Testing
@testable import PluginConversationInput

@MainActor
@Suite("SendActionBarViewModel")
struct SendActionBarViewModelTests {
    // MARK: - Initial state

    @Test("初始状态镜像能力层的输入文本与当前回合")
    func initialStateMirrorsCapability() throws {
        let conversationID = UUID()
        let capability = SendActionBarTestCapability()
        capability.text = "hello"
        capability.selectedConversationID = conversationID
        capability.sendingConversationIDs = [conversationID]

        let viewModel = SendActionBarViewModel(capability: capability)

        #expect(viewModel.state.canStop)
        #expect(viewModel.state.canSend)
        #expect(viewModel.state.showsStopButton)
        #expect(!viewModel.state.showsSendButton)
    }

    @Test("没有选中会话时不显示发送中")
    func initialStateWithoutSelectionIsNotSending() {
        let capability = SendActionBarTestCapability()

        let viewModel = SendActionBarViewModel(capability: capability)

        #expect(!viewModel.state.canStop)
        #expect(!viewModel.state.canSend)
        #expect(viewModel.state.showsSendButton)
    }

    @Test("挂起等待用户时同样显示停止按钮")
    func suspendedConversationShowsStopButton() {
        let conversationID = UUID()
        let capability = SendActionBarTestCapability()
        capability.selectedConversationID = conversationID
        capability.suspendedConversationIDs = [conversationID]

        let viewModel = SendActionBarViewModel(capability: capability)

        // 挂起也是「回合还没干完」：用户必须能停它。
        #expect(viewModel.state.canStop)
        #expect(viewModel.state.showsStopButton)
        #expect(!viewModel.state.showsSendButton)
    }

    // MARK: - canSend

    @Test("纯空白输入不可发送")
    func whitespaceOnlyInputCannotSend() {
        let capability = SendActionBarTestCapability()
        let viewModel = SendActionBarViewModel(capability: capability)

        viewModel.updateInputText("   \n\t ")

        #expect(!viewModel.state.canSend)
    }

    @Test("仅有附件时同样可以发送")
    func attachmentsAloneEnableSend() {
        let capability = SendActionBarTestCapability()
        let viewModel = SendActionBarViewModel(capability: capability)

        viewModel.updateAttachments()

        #expect(!viewModel.state.canSend)

        capability.pendingImageAttachments = [
            UserImageAttachment(mimeType: "image/png", base64Data: "AAAA")
        ]
        viewModel.updateAttachments()

        #expect(viewModel.state.canSend)
    }

    @Test("附件被移除后恢复为不可发送")
    func removingAttachmentsDisablesSend() {
        let capability = SendActionBarTestCapability()
        capability.pendingFileAttachments = [
            UserFileAttachment(fileName: "notes.txt", mimeType: "text/plain", textContent: "notes")
        ]
        let viewModel = SendActionBarViewModel(capability: capability)

        #expect(viewModel.state.canSend)

        capability.pendingFileAttachments = []
        viewModel.updateAttachments()

        #expect(!viewModel.state.canSend)
    }

    // MARK: - Send

    @Test("空白输入且无附件时不提交任何消息")
    func sendIgnoresBlankInput() {
        let capability = SendActionBarTestCapability()
        capability.text = "   "
        let viewModel = SendActionBarViewModel(capability: capability)

        viewModel.send()

        #expect(capability.commits.isEmpty)
        #expect(capability.backgroundCommits.isEmpty)
        // 未真正发送，输入框内容不应被清空。
        #expect(capability.text == "   ")
        #expect(capability.startedCommits.isEmpty)
    }

    @Test("纯文本走同步提交并随后启动回合")
    func sendCommitsTrimmedTextSynchronously() async throws {
        let conversationID = UUID()
        let capability = SendActionBarTestCapability()
        capability.text = "  hello world  "
        capability.commit = MessageSendCommit(conversationID: conversationID, userMessageID: UUID())
        let viewModel = SendActionBarViewModel(capability: capability)

        viewModel.send()

        let commit = try #require(capability.commits.first)
        #expect(commit.content == "hello world")
        // 发送时显式传 nil，由发送能力解析目标会话。
        #expect(commit.conversationID == nil)
        #expect(commit.usedBackgroundPath == false)
        // 提交后输入框立即清空，错误提示一并复位。
        #expect(capability.text.isEmpty)
        #expect(capability.errorMessage == nil)
        // 附件路径必须完全绕开同步提交。
        #expect(capability.backgroundCommits.isEmpty)

        await waitUntil("回合未在提交后启动") {
            capability.startedCommits.count == 1
        }
        #expect(capability.startedCommits.first?.conversationID == conversationID)
    }

    @Test("带附件的消息走后台编码提交")
    func sendUsesBackgroundPathForAttachments() async throws {
        let conversationID = UUID()
        let capability = SendActionBarTestCapability()
        capability.text = "look"
        capability.pendingImageAttachments = [
            UserImageAttachment(mimeType: "image/png", base64Data: "AAAA")
        ]
        capability.commit = MessageSendCommit(conversationID: conversationID, userMessageID: UUID())
        let viewModel = SendActionBarViewModel(capability: capability)

        viewModel.send()

        #expect(capability.commits.isEmpty)
        await waitUntil("附件消息未走后台提交") {
            !capability.backgroundCommits.isEmpty
        }
        let commit = try #require(capability.backgroundCommits.first)
        #expect(commit.imageAttachments.count == 1)
        #expect(commit.usedBackgroundPath)
        await waitUntil("附件消息提交后未启动回合") {
            capability.startedCommits.count == 1
        }
    }

    @Test("排队的消息不会启动回合")
    func queuedCommitDoesNotStartTurn() async throws {
        let capability = SendActionBarTestCapability()
        capability.text = "queued"
        capability.commit = MessageSendCommit(conversationID: UUID(), userMessageID: nil)
        let viewModel = SendActionBarViewModel(capability: capability)

        viewModel.send()

        #expect(capability.commits.count == 1)
        await awaitSettle()
        #expect(capability.startedCommits.isEmpty)
    }

    @Test("提交返回 nil 时不启动回合")
    func nilCommitDoesNotStartTurn() async throws {
        let capability = SendActionBarTestCapability()
        capability.text = "dropped"
        capability.commit = nil
        let viewModel = SendActionBarViewModel(capability: capability)

        viewModel.send()

        #expect(capability.commits.count == 1)
        await awaitSettle()
        #expect(capability.startedCommits.isEmpty)
    }

    @Test("提交失败时把错误写入错误状态")
    func sendPropagatesCommitFailure() {
        let capability = SendActionBarTestCapability()
        capability.text = "boom"
        capability.commitError = SendActionBarTestError.failed
        let viewModel = SendActionBarViewModel(capability: capability)

        viewModel.send()

        #expect(capability.errorMessage == SendActionBarTestError.failed.localizedDescription)
        #expect(capability.startedCommits.isEmpty)
    }

    @Test("发送前清除旧的错误提示")
    func sendClearsPreviousError() throws {
        let capability = SendActionBarTestCapability()
        capability.errorMessage = "stale error"
        capability.text = "ok"
        capability.commit = MessageSendCommit(conversationID: UUID(), userMessageID: UUID())
        let viewModel = SendActionBarViewModel(capability: capability)

        viewModel.send()

        #expect(capability.errorMessage == nil)
    }

    // MARK: - Cancel

    @Test("停止按钮取消当前请求")
    func cancelDelegatesToCapability() {
        let capability = SendActionBarTestCapability()
        let viewModel = SendActionBarViewModel(capability: capability)

        viewModel.cancel()

        #expect(capability.cancelCount == 1)
    }

    // MARK: - Conversation state

    @Test("刷新会话状态读取当前会话的发送中标记")
    func refreshConversationStateReadsSelectedConversation() {
        let first = UUID()
        let second = UUID()
        let capability = SendActionBarTestCapability()
        capability.selectedConversationID = first
        capability.sendingConversationIDs = [second]
        let viewModel = SendActionBarViewModel(capability: capability)

        #expect(!viewModel.state.canStop)

        capability.selectedConversationID = second
        viewModel.refreshConversationState()

        #expect(viewModel.state.canStop)
    }

    @Test("没有选中会话时刷新会复位发送中标记")
    func refreshConversationStateClearsWithoutSelection() {
        let conversationID = UUID()
        let capability = SendActionBarTestCapability()
        capability.selectedConversationID = conversationID
        capability.sendingConversationIDs = [conversationID]
        let viewModel = SendActionBarViewModel(capability: capability)

        #expect(viewModel.state.canStop)

        capability.selectedConversationID = nil
        viewModel.refreshConversationState()

        #expect(!viewModel.state.canStop)
    }
}

// MARK: - Support

enum SendActionBarTestError: LocalizedError {
    case failed
    case timedOut(String)

    var errorDescription: String? {
        switch self {
        case .failed: "commit failed"
        case .timedOut(let message): message
        }
    }
}

struct SendActionBarTestCommit: Equatable {
    let content: String
    let conversationID: UUID?
    let imageAttachments: [UserImageAttachment]
    let fileAttachments: [UserFileAttachment]
    let usedBackgroundPath: Bool
}

/// 记录调用并可手动推送事件的 `ConversationInputCapability` 测试替身。
@MainActor
final class SendActionBarTestCapability: ConversationInputCapability {
    // MARK: - Recorded calls

    private(set) var commits: [SendActionBarTestCommit] = []
    private(set) var backgroundCommits: [SendActionBarTestCommit] = []
    private(set) var startedCommits: [MessageSendCommit] = []
    private(set) var cancelCount = 0
    private(set) var clearInputCount = 0
    private(set) var clearedAttachments = false

    /// 同步与后台提交共用的返回值 / 错误。
    var commit: MessageSendCommit?
    var commitError: (any Error)?

    // MARK: - State

    /// 模拟真实 `DefaultConversationInputProvider.text` 的 `didSet` 通知语义：
    /// 文本**实际发生变化**时同步通知全部文本观察者。
    ///
    /// 默认关闭。既有测试大多直接赋值 `capability.text` 只为给 ViewModel 铺初始
    /// 状态，并不关心通知；开启后会让这些用例多走一轮 Observer 回环。性能相关的
    /// 测试需要显式打开，才能复现生产链路里「写能力层 → 观察者回灌」的完整回路。
    var notifiesTextObserversOnSet = false

    var text: String = "" {
        didSet {
            guard notifiesTextObserversOnSet, text != oldValue else { return }
            notifyTextObservers(text)
        }
    }
    var inputHeight: CGFloat = 40
    var isInputFocused = false
    var inputCursorPosition = 0
    var errorMessage: String?
    var pendingImageAttachments: [UserImageAttachment] = []
    var pendingFileAttachments: [UserFileAttachment] = []
    var selectedConversationID: UUID?
    /// 回合正在产出（`agentLoopState == .running`）的会话。
    var sendingConversationIDs: Set<UUID> = []
    /// 回合挂在等用户授权/回答（`agentLoopState == .suspended`）的会话。
    var suspendedConversationIDs: Set<UUID> = []

    // MARK: - Input

    func clearInput() {
        clearInputCount += 1
        text = ""
    }

    // MARK: - Attachments

    func addImageAttachment(_ attachment: UserImageAttachment) {
        pendingImageAttachments.append(attachment)
    }

    func addFileAttachment(_ attachment: UserFileAttachment) {
        pendingFileAttachments.append(attachment)
    }

    func removeImageAttachment(id: UUID) {
        pendingImageAttachments.removeAll { $0.id == id }
    }

    func removeFileAttachment(id: UUID) {
        pendingFileAttachments.removeAll { $0.id == id }
    }

    func clearAttachments() {
        pendingImageAttachments = []
        pendingFileAttachments = []
        clearedAttachments = true
    }

    // MARK: - Send

    func commitUserMessage(
        _ content: String,
        imageAttachments: [UserImageAttachment],
        fileAttachments: [UserFileAttachment],
        conversationID: UUID?
    ) throws -> MessageSendCommit? {
        commits.append(
            SendActionBarTestCommit(
                content: content,
                conversationID: conversationID,
                imageAttachments: imageAttachments,
                fileAttachments: fileAttachments,
                usedBackgroundPath: false
            )
        )
        if let commitError { throw commitError }
        return commit
    }

    func commitUserMessageInBackground(
        _ content: String,
        imageAttachments: [UserImageAttachment],
        fileAttachments: [UserFileAttachment],
        conversationID: UUID?
    ) async throws -> MessageSendCommit? {
        backgroundCommits.append(
            SendActionBarTestCommit(
                content: content,
                conversationID: conversationID,
                imageAttachments: imageAttachments,
                fileAttachments: fileAttachments,
                usedBackgroundPath: true
            )
        )
        if let commitError { throw commitError }
        return commit
    }

    func startTurn(for commit: MessageSendCommit) async {
        startedCommits.append(commit)
    }

    func cancelCurrentRequest() {
        cancelCount += 1
    }

    // MARK: - Conversation / sending state

    func isSending(for conversationID: UUID?) -> Bool {
        guard let conversationID else { return false }
        return sendingConversationIDs.contains(conversationID)
    }

    func canStop(for conversationID: UUID?) -> Bool {
        guard let conversationID else { return false }
        return sendingConversationIDs.contains(conversationID)
            || suspendedConversationIDs.contains(conversationID)
    }

    // MARK: - Observation

    private var textObservers: [UUID: (String) -> Void] = [:]
    private var senderObservers: [UUID: (MessageSenderEvent) -> Void] = [:]
    private var selectedConversationObservers: [UUID: (UUID?) -> Void] = [:]
    private var conversationStateObservers: [UUID: (ConversationStateEvent) -> Void] = [:]
    private var blockObservers: [UUID: (ConversationInputBlockProvidingEvent) -> Void] = [:]
    private var inputObservers: [UUID: (ConversationInputProvidingEvent) -> Void] = [:]

    func addTextObserver(
        _ callback: @escaping (String) -> Void
    ) -> any TextInputObserverHandle {
        let id = UUID()
        textObservers[id] = callback
        return SendActionBarTestHandle(cancel: { [weak self] in self?.textObservers.removeValue(forKey: id) })
    }

    func addBlockObserver(
        _ callback: @escaping (ConversationInputBlockProvidingEvent) -> Void
    ) -> any ConversationInputBlockObserverHandle {
        let id = UUID()
        blockObservers[id] = callback
        return SendActionBarTestHandle(cancel: { [weak self] in self?.blockObservers.removeValue(forKey: id) })
    }

    func addInputObserver(
        _ callback: @escaping (ConversationInputProvidingEvent) -> Void
    ) -> any ConversationInputProvidingObserverHandle {
        let id = UUID()
        inputObservers[id] = callback
        return SendActionBarTestHandle(cancel: { [weak self] in self?.inputObservers.removeValue(forKey: id) })
    }

    func addMessageSenderObserver(
        _ callback: @escaping (MessageSenderEvent) -> Void
    ) -> any MessageSenderObserverHandle {
        let id = UUID()
        senderObservers[id] = callback
        return SendActionBarTestHandle(cancel: { [weak self] in self?.senderObservers.removeValue(forKey: id) })
    }

    func addSelectedConversationObserver(
        _ callback: @escaping (UUID?) -> Void
    ) -> any SelectedConversationObserverHandle {
        let id = UUID()
        selectedConversationObservers[id] = callback
        return SendActionBarTestHandle(cancel: { [weak self] in self?.selectedConversationObservers.removeValue(forKey: id) })
    }

    func addConversationStateObserver(
        _ callback: @escaping (ConversationStateEvent) -> Void
    ) -> any ConversationStateObserverHandle {
        let id = UUID()
        conversationStateObservers[id] = callback
        return SendActionBarTestHandle(cancel: { [weak self] in self?.conversationStateObservers.removeValue(forKey: id) })
    }

    /// 同步通知全部文本观察者。
    private func notifyTextObservers(_ text: String) {
        for callback in textObservers.values { callback(text) }
    }

    /// 推送输入文本变化。
    func emitText(_ text: String) {
        self.text = text
        notifyTextObservers(text)
    }

    /// 推送附件变化。
    func emitAttachmentsChanged() {
        for callback in senderObservers.values { callback(.attachmentsChanged) }
    }

    /// 推送会话状态变化。
    func emitConversationState(_ event: ConversationStateEvent) {
        for callback in conversationStateObservers.values { callback(event) }
    }

    /// 推送选中会话变化。
    func emitSelectedConversation(_ id: UUID?) {
        selectedConversationID = id
        for callback in selectedConversationObservers.values { callback(id) }
    }

    /// 推送错误提示变化。
    func emitErrorMessageChanged(_ message: String?) {
        errorMessage = message
        for callback in inputObservers.values { callback(.errorMessageChanged(message)) }
    }

    /// 推送折叠块递交。
    func emitBlockSubmitted(_ block: ConversationInputBlock) {
        for callback in blockObservers.values { callback(.blockSubmitted(block)) }
    }

    /// 推送回合开始事件。
    func emitTurnStarted(conversationID: UUID) {
        for callback in senderObservers.values { callback(.started(conversationID: conversationID)) }
    }

    /// 推送回合结束事件。
    func emitTurnCompleted(conversationID: UUID, outcome: AgentLoopOutcome) {
        for callback in senderObservers.values {
            callback(.turnCompleted(conversationID: conversationID, outcome: outcome))
        }
    }

    // MARK: - Metrics

    func beginMetrics(operation: String, metadata: [String: String]) -> PerformanceTrace? { nil }
    func markMetrics(_ trace: PerformanceTrace, stage: String) {}
    func endMetrics(_ trace: PerformanceTrace) {}
}

/// 同时满足插件能力协议里多种观察句柄要求的轻量句柄。
@MainActor
final class SendActionBarTestHandle: TextInputObserverHandle, MessageSenderObserverHandle,
    SelectedConversationObserverHandle, ConversationStateObserverHandle,
    ConversationInputProvidingObserverHandle, ConversationInputBlockObserverHandle
{
    private let onCancel: () -> Void

    init(cancel: @escaping () -> Void) {
        self.onCancel = cancel
    }

    func cancel() { onCancel() }
}

// MARK: - Async helpers

/// 轮询直到条件成立（发送路径含 `Task { @MainActor }` 调度）。
@MainActor
func waitUntil(
    _ description: String,
    timeout: Duration = .seconds(2),
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: () -> Bool
) async {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return }
        try? await Task.sleep(for: .milliseconds(5))
    }
    Issue.record(
        SendActionBarTestError.timedOut("\(description) 未在 \(timeout) 内成立"),
        sourceLocation: sourceLocation
    )
}

/// 让挂起的 `Task { @MainActor }` 有机会跑完一轮。
@MainActor
func awaitSettle(milliseconds: Int = 50) async {
    try? await Task.sleep(for: .milliseconds(milliseconds))
}
