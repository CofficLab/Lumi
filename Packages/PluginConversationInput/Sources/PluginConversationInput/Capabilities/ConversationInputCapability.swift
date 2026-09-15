import Foundation
import ProviderConversation
import ProviderConversationInput
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
        conversationID: UUID?
    ) throws -> MessageSendCommit?

    func commitUserMessageInBackground(
        _ content: String,
        imageAttachments: [UserImageAttachment],
        fileAttachments: [UserFileAttachment],
        conversationID: UUID?
    ) async throws -> MessageSendCommit?

    func startTurn(for commit: MessageSendCommit) async

    func cancelCurrentRequest()

    // MARK: - Conversation / sending state

    var selectedConversationID: UUID? { get }
    func isSending(for conversationID: UUID?) -> Bool

    // MARK: - Observation

    @discardableResult
    func addTextObserver(_ callback: @escaping (String) -> Void) -> any TextInputObserverHandle

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
    private let sender: (any MessageSendingProviding)?
    private let conversations: (any ConversationManaging)?
    private let conversationState: (any ConversationStateProviding)?
    private let metrics: (any PerformanceMetricsProviding)?

    init(
        input: (any ConversationInputProviding)?,
        sender: (any MessageSendingProviding)?,
        conversations: (any ConversationManaging)?,
        conversationState: (any ConversationStateProviding)?,
        metrics: (any PerformanceMetricsProviding)?
    ) {
        self.input = input
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

    func clearInput() {
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
        conversationID: UUID?
    ) throws -> MessageSendCommit? {
        guard let sender else { return nil }
        return try sender.commitUserMessage(
            content,
            imageAttachments: imageAttachments,
            fileAttachments: fileAttachments,
            conversationID: conversationID
        )
    }

    func commitUserMessageInBackground(
        _ content: String,
        imageAttachments: [UserImageAttachment],
        fileAttachments: [UserFileAttachment],
        conversationID: UUID?
    ) async throws -> MessageSendCommit? {
        guard let sender else { return nil }
        return try await sender.commitUserMessageInBackground(
            content,
            imageAttachments: imageAttachments,
            fileAttachments: fileAttachments,
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

    // MARK: - Observation

    func addTextObserver(
        _ callback: @escaping (String) -> Void
    ) -> any TextInputObserverHandle {
        input?.addTextObserver(callback) ?? NoopTextInputObserverHandle()
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
