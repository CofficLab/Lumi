import Foundation
import ProviderConversation
import ProviderConversationInput
import ProviderConversationInputBlock
import ProviderConversationState
import ProviderMessage
import ProviderMessageSender
import ProviderPerformanceMetrics
import SwiftUI

/// 输入框插件所需的最小输入/发送能力。
///
/// 收敛 `ConversationInputProviding`、`MessageSendingProviding`、
/// `ConversationManaging`、`ConversationStateProviding` 与
/// `PerformanceMetricsProviding` 的调用面，ViewModel 与 Observer 只依赖本能力。
@MainActor
protocol ConversationInputCapability: AnyObject {
    // MARK: - Input

    var text: String { get set }
    var inputHeight: CGFloat { get set }
    var isInputFocused: Bool { get set }
    var inputCursorPosition: Int { get set }
    var errorMessage: String? { get set }
    /// 草稿里的折叠块区间（以草稿文本为基准）。
    ///
    /// 放在能力层而不是某一个 ViewModel，是因为**两条发送路径**都要用到它：
    /// 回车发送（`ConversationInputViewModel`）与发送按钮
    /// （`SendActionBarViewModel`）。折叠块与正文一样属于草稿状态，
    /// 能力层是它唯一的存放处，两个 ViewModel 都从这里读，天然一致。
    var collapsedBlocks: [CollapsedContentBlock] { get set }
    func clearInput()

    // MARK: - Attachments

    var pendingImageAttachments: [UserImageAttachment] { get }
    var pendingFileAttachments: [UserFileAttachment] { get }
    func addImageAttachment(_ attachment: UserImageAttachment)
    func addFileAttachment(_ attachment: UserFileAttachment)
    func removeImageAttachment(id: UUID)
    func removeFileAttachment(id: UUID)
    func clearAttachments()

    // MARK: - Send

    func commitUserMessage(
        _ content: String,
        imageAttachments: [UserImageAttachment],
        fileAttachments: [UserFileAttachment],
        collapsedBlocks: [CollapsedContentBlock],
        conversationID: UUID?
    ) throws -> MessageSendCommit?

    func commitUserMessageInBackground(
        _ content: String,
        imageAttachments: [UserImageAttachment],
        fileAttachments: [UserFileAttachment],
        collapsedBlocks: [CollapsedContentBlock],
        conversationID: UUID?
    ) async throws -> MessageSendCommit?

    func startTurn(for commit: MessageSendCommit) async

    func cancelCurrentRequest()

    // MARK: - Conversation / sending state

    var selectedConversationID: UUID? { get }
    func isSending(for conversationID: UUID?) -> Bool

    /// 该会话是否还有未完成的回合（运行中，或挂在等用户授权/回答）。
    ///
    /// 停止按钮的可见性由它决定：只要还有活没干完，就给用户一个停止入口。
    func canStop(for conversationID: UUID?) -> Bool

    // MARK: - Observation

    @discardableResult
    func addTextObserver(_ callback: @escaping (String) -> Void) -> any TextInputObserverHandle

    /// 注册折叠内容块观察者。生产方（如代码编辑器选区发送到对话）递交的块
    /// 由 ViewModel 转成待插入请求交给编辑器渲染。
    @discardableResult
    func addBlockObserver(
        _ callback: @escaping (ConversationInputBlockProvidingEvent) -> Void
    ) -> any ConversationInputBlockObserverHandle

    @discardableResult
    func addInputObserver(
        _ callback: @escaping (ConversationInputProvidingEvent) -> Void
    ) -> any ConversationInputProvidingObserverHandle

    @discardableResult
    func addMessageSenderObserver(
        _ callback: @escaping (MessageSenderEvent) -> Void
    ) -> any MessageSenderObserverHandle

    @discardableResult
    func addSelectedConversationObserver(
        _ callback: @escaping (UUID?) -> Void
    ) -> any SelectedConversationObserverHandle

    @discardableResult
    func addConversationStateObserver(
        _ callback: @escaping (ConversationStateEvent) -> Void
    ) -> any ConversationStateObserverHandle

    // MARK: - Metrics

    func beginMetrics(operation: String, metadata: [String: String]) -> PerformanceTrace?
    func markMetrics(_ trace: PerformanceTrace, stage: String)
    func endMetrics(_ trace: PerformanceTrace)
}

/// 将输入/发送相关 Provider 适配为插件能力。
@MainActor
final class ConversationInputCapabilityAdapter: ConversationInputCapability {
    private let input: (any ConversationInputProviding)?
    private let blocks: (any ConversationInputBlockProviding)?
    private let sender: (any MessageSendingProviding)?
    private let conversations: (any ConversationManaging)?
    private let conversationState: (any ConversationStateProviding)?
    private let metrics: (any PerformanceMetricsProviding)?
    /// 草稿里的折叠块区间。草稿级状态，随正文一起清空。
    private var storedCollapsedBlocks: [CollapsedContentBlock] = []

    init(
        input: (any ConversationInputProviding)?,
        blocks: (any ConversationInputBlockProviding)? = nil,
        sender: (any MessageSendingProviding)?,
        conversations: (any ConversationManaging)?,
        conversationState: (any ConversationStateProviding)?,
        metrics: (any PerformanceMetricsProviding)?
    ) {
        self.input = input
        self.blocks = blocks
        self.sender = sender
        self.conversations = conversations
        self.conversationState = conversationState
        self.metrics = metrics
    }

    // MARK: - Input

    var text: String {
        get { input?.text ?? "" }
        set { input?.text = newValue }
    }

    var inputHeight: CGFloat {
        get { input?.inputHeight ?? ChatInputEditorView.minHeight }
        set { input?.inputHeight = newValue }
    }

    var isInputFocused: Bool {
        get { input?.isInputFocused ?? false }
        set { input?.isInputFocused = newValue }
    }

    var inputCursorPosition: Int {
        get { input?.inputCursorPosition ?? 0 }
        set { input?.inputCursorPosition = newValue }
    }

    var errorMessage: String? {
        get { input?.errorMessage }
        set { input?.errorMessage = newValue }
    }

    var collapsedBlocks: [CollapsedContentBlock] {
        get { storedCollapsedBlocks }
        set { storedCollapsedBlocks = newValue }
    }

    func clearInput() {
        storedCollapsedBlocks = []
        input?.clear()
    }

    // MARK: - Attachments

    var pendingImageAttachments: [UserImageAttachment] {
        sender?.pendingImageAttachments ?? []
    }

    var pendingFileAttachments: [UserFileAttachment] {
        sender?.pendingFileAttachments ?? []
    }

    func addImageAttachment(_ attachment: UserImageAttachment) {
        sender?.addImageAttachment(attachment)
    }

    func addFileAttachment(_ attachment: UserFileAttachment) {
        sender?.addFileAttachment(attachment)
    }

    func removeImageAttachment(id: UUID) {
        sender?.removeImageAttachment(id: id)
    }

    func removeFileAttachment(id: UUID) {
        sender?.removeFileAttachment(id: id)
    }

    func clearAttachments() {
        sender?.clearImageAttachments()
        sender?.clearFileAttachments()
    }

    // MARK: - Send

    func commitUserMessage(
        _ content: String,
        imageAttachments: [UserImageAttachment],
        fileAttachments: [UserFileAttachment],
        collapsedBlocks: [CollapsedContentBlock],
        conversationID: UUID?
    ) throws -> MessageSendCommit? {
        guard let sender else { return nil }
        return try sender.commitUserMessage(
            content,
            imageAttachments: imageAttachments,
            fileAttachments: fileAttachments,
            collapsedBlocks: collapsedBlocks,
            conversationID: conversationID
        )
    }

    func commitUserMessageInBackground(
        _ content: String,
        imageAttachments: [UserImageAttachment],
        fileAttachments: [UserFileAttachment],
        collapsedBlocks: [CollapsedContentBlock],
        conversationID: UUID?
    ) async throws -> MessageSendCommit? {
        guard let sender else { return nil }
        return try await sender.commitUserMessageInBackground(
            content,
            imageAttachments: imageAttachments,
            fileAttachments: fileAttachments,
            collapsedBlocks: collapsedBlocks,
            conversationID: conversationID
        )
    }

    func startTurn(for commit: MessageSendCommit) async {
        await sender?.startTurn(for: commit)
    }

    func cancelCurrentRequest() {
        sender?.cancelCurrentRequest()
    }

    // MARK: - Conversation / sending state

    var selectedConversationID: UUID? {
        conversations?.selectedConversationID
    }

    func isSending(for conversationID: UUID?) -> Bool {
        guard let conversationID else { return false }
        return conversationState?.state(for: conversationID).isSending ?? false
    }

    func canStop(for conversationID: UUID?) -> Bool {
        guard let conversationID else { return false }
        return conversationState?.state(for: conversationID).canStop ?? false
    }

    // MARK: - Observation

    func addTextObserver(
        _ callback: @escaping (String) -> Void
    ) -> any TextInputObserverHandle {
        input?.addTextObserver(callback) ?? NoopTextInputObserverHandle()
    }

    func addBlockObserver(
        _ callback: @escaping (ConversationInputBlockProvidingEvent) -> Void
    ) -> any ConversationInputBlockObserverHandle {
        blocks?.addObserver(callback) ?? NoopConversationInputBlockObserverHandle()
    }

    func addInputObserver(
        _ callback: @escaping (ConversationInputProvidingEvent) -> Void
    ) -> any ConversationInputProvidingObserverHandle {
        input?.addObserver(callback) ?? NoopConversationInputProvidingObserverHandle()
    }

    func addMessageSenderObserver(
        _ callback: @escaping (MessageSenderEvent) -> Void
    ) -> any MessageSenderObserverHandle {
        sender?.addMessageSenderObserver(callback) ?? NoopMessageSenderObserverHandle()
    }

    func addSelectedConversationObserver(
        _ callback: @escaping (UUID?) -> Void
    ) -> any SelectedConversationObserverHandle {
        conversations?.addSelectedConversationObserver(callback) ?? NoopSelectedConversationObserverHandle()
    }

    func addConversationStateObserver(
        _ callback: @escaping (ConversationStateEvent) -> Void
    ) -> any ConversationStateObserverHandle {
        conversationState?.addConversationStateObserver(callback) ?? NoopConversationStateObserverHandle()
    }

    // MARK: - Metrics

    func beginMetrics(operation: String, metadata: [String: String]) -> PerformanceTrace? {
        metrics?.begin(operation: operation, metadata: metadata)
    }

    func markMetrics(_ trace: PerformanceTrace, stage: String) {
        metrics?.mark(trace, stage: stage)
    }

    func endMetrics(_ trace: PerformanceTrace) {
        metrics?.end(trace)
    }
}

// MARK: - Noop 句柄（Provider 缺失时的空实现）

private final class NoopTextInputObserverHandle: TextInputObserverHandle {
    func cancel() {}
}

private final class NoopMessageSenderObserverHandle: MessageSenderObserverHandle {
    func cancel() {}
}
