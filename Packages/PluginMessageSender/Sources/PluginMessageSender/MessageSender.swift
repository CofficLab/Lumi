import Foundation
import os
import KitSuperLog
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderMessageSender

/// 插件自带的 `MessageSendingProviding` 实现。
@MainActor
public final class MessageSender: MessageSendingProviding, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin-message-sender",
        category: "MessageSender"
    )
    nonisolated public static let emoji = "📤"
    nonisolated static let verbose = false

    private let conversations: any ConversationManaging
    private let messages: any MessageManaging
    private let agentLoop: any AgentLoopProviding
    private var currentTasks: [UUID: Task<Void, Never>] = [:]
    /// 消息已同步提交，但回合跟踪任务尚未被调度；用于保留连续发送的串行语义。
    private var pendingTurnStarts: Set<UUID> = []
    private var pendingOutcomes: [UUID: [CheckedContinuation<AgentLoopOutcome, Never>]] = [:]
    private var completedOutcomes: [UUID: AgentLoopOutcome] = [:]
    private var messageSenderObservers: [UUID: (MessageSenderEvent) -> Void] = [:]

    @Published public private(set) var isSending = false {
        didSet {
            guard isSending != oldValue else { return }
            notifySendingStateObservers()
        }
    }
    @Published public private(set) var pendingImageAttachments: [UserImageAttachment] = []
    @Published public private(set) var pendingFileAttachments: [UserFileAttachment] = []
    @Published public private(set) var pendingQueues: [UUID: [PendingChatMessage]] = [:]

    // MARK: - Sending State Observation

    private var sendingStateObservers: [WeakSendingStateObserver] = []

    @discardableResult
    public func addSendingStateObserver(_ callback: @escaping (Bool) -> Void) -> any SendingStateObserverHandle {
        let handle = SendingStateObserverHandleImpl(owner: self, callback: callback)
        sendingStateObservers.append(WeakSendingStateObserver(handle))
        return handle
    }

    fileprivate func removeSendingStateObserver(_ handle: SendingStateObserverHandleImpl) {
        sendingStateObservers.removeAll { $0.handle === handle }
    }

    private func notifySendingStateObservers() {
        sendingStateObservers.removeAll { $0.handle == nil }
        let observers = sendingStateObservers
        let currentState = isSending
        for observer in observers {
            observer.handle?.invoke(currentState)
        }
    }

    public init(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        agentLoop: any AgentLoopProviding
    ) {
        self.conversations = conversations
        self.messages = messages
        self.agentLoop = agentLoop
    }

    @discardableResult
    public func addMessageSenderObserver(
        _ callback: @escaping (MessageSenderEvent) -> Void
    ) -> any MessageSenderObserverHandle {
        let id = UUID()
        messageSenderObservers[id] = callback
        return MessageSenderObserverHandleImpl { [weak self] in
            self?.messageSenderObservers.removeValue(forKey: id)
        }
    }

    private func notify(_ event: MessageSenderEvent) {
        for callback in messageSenderObservers.values {
            callback(event)
        }
    }

    // MARK: - Attachments（挂起池）

    public func addImageAttachment(_ attachment: UserImageAttachment) {
        pendingImageAttachments.append(attachment)
    }

    public func removeImageAttachment(id: UUID) {
        pendingImageAttachments.removeAll { $0.id == id }
    }

    public func clearImageAttachments() {
        pendingImageAttachments = []
    }

    public func addFileAttachment(_ attachment: UserFileAttachment) {
        pendingFileAttachments.append(attachment)
    }

    public func removeFileAttachment(id: UUID) {
        pendingFileAttachments.removeAll { $0.id == id }
    }

    public func clearFileAttachments() {
        pendingFileAttachments = []
    }

    // MARK: - Pending Queue

    public func pendingMessages(for conversationID: UUID) -> [PendingChatMessage] {
        pendingQueues[conversationID] ?? []
    }

    public func cancelPendingMessage(id: UUID, in conversationID: UUID) {
        guard var queue = pendingQueues[conversationID] else { return }
        queue.removeAll { $0.id == id }
        if queue.isEmpty {
            pendingQueues.removeValue(forKey: conversationID)
        } else {
            pendingQueues[conversationID] = queue
        }
    }

    // MARK: - Send

    public func sendMessage(_ content: String, conversationID: UUID?) async throws {
        guard let commit = try commitUserMessage(
            content,
            imageAttachments: pendingImageAttachments,
            fileAttachments: pendingFileAttachments,
            conversationID: conversationID
        ) else { return }
        await startTurn(for: commit)
    }

    @discardableResult
    public func commitUserMessage(_ content: String, conversationID: UUID?) throws -> MessageSendCommit? {
        try commitUserMessage(
            content,
            imageAttachments: pendingImageAttachments,
            fileAttachments: pendingFileAttachments,
            conversationID: conversationID
        )
    }

    @discardableResult
    public func commitUserMessage(
        _ content: String,
        imageAttachments: [UserImageAttachment],
        fileAttachments: [UserFileAttachment],
        conversationID: UUID?
    ) throws -> MessageSendCommit? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasAttachments = !imageAttachments.isEmpty || !fileAttachments.isEmpty
        guard !trimmed.isEmpty || hasAttachments else {
            if Self.verbose {
                Self.logger.debug("\(Self.t)sendMessage ignored: empty content after trim")
            }
            return nil
        }

        let targetID: UUID
        if let conversationID {
            targetID = conversationID
        } else if let selected = conversations.selectedConversationID {
            targetID = selected
        } else {
            targetID = try conversations.createConversation(
                title: nil,
                projectPath: nil,
                providerID: nil,
                modelName: nil
            )
            if Self.verbose {
                Self.logger.info("\(self.t)created new conversation \(targetID.uuidString) for send")
            }
        }
        // 新建会话必须成为当前时间线，否则消息落进不可见会话。
        if conversations.selectedConversationID != targetID {
            conversations.selectConversation(id: targetID)
        }

        // 同一会话发送中：入队，当前回合结束后依次发出。
        if isSending(for: targetID) {
            pendingQueues[targetID, default: []].append(PendingChatMessage(
                conversationID: targetID,
                content: trimmed,
                imageAttachments: imageAttachments,
                fileAttachments: fileAttachments
            ))
            clearSentAttachments(imageAttachments, fileAttachments)
            if Self.verbose {
                Self.logger.info("\(self.t)send queued: conversation=\(targetID.uuidString.prefix(8)), queueDepth=\(self.pendingQueues[targetID]?.count ?? 0)")
            }
            return MessageSendCommit(conversationID: targetID, userMessageID: nil)
        }

        // 附件编码进 metadata（图片 + 文件并行）。
        var metadata: [String: String] = [:]
        metadata.merge(UserAttachmentMetadata.encodeImageAttachments(imageAttachments)) { _, new in new }
        metadata.merge(UserAttachmentMetadata.encodeFileAttachments(fileAttachments)) { _, new in new }

        let userMessage = Message(
            conversationID: targetID,
            role: .user,
            content: trimmed,
            metadata: metadata
        )
        completedOutcomes.removeValue(forKey: targetID)
        pendingTurnStarts.insert(targetID)
        messages.insertMessage(userMessage, to: targetID)
        clearSentAttachments(imageAttachments, fileAttachments)
        if Self.verbose {
            Self.logger.info("\(self.t)send user message: conversation=\(targetID.uuidString.prefix(8)), message=\(userMessage.id.uuidString.prefix(8)), contentChars=\(trimmed.count), images=\(imageAttachments.count), files=\(fileAttachments.count)")
        }

        return MessageSendCommit(conversationID: targetID, userMessageID: userMessage.id)
    }

    public func startTurn(for commit: MessageSendCommit) async {
        guard let userMessageID = commit.userMessageID else { return }
        pendingTurnStarts.remove(commit.conversationID)
        await executeTurn(conversationID: commit.conversationID, userMessageID: userMessageID)
    }

    public func sendMessage(
        _ content: String,
        imageAttachments: [UserImageAttachment],
        fileAttachments: [UserFileAttachment],
        conversationID: UUID?
    ) async throws {
        guard let commit = try commitUserMessage(
            content,
            imageAttachments: imageAttachments,
            fileAttachments: fileAttachments,
            conversationID: conversationID
        ) else { return }
        await startTurn(for: commit)
    }

    public func cancelCurrentRequest() {
        if Self.verbose {
            Self.logger.info("\(self.t)cancel current request: activeTasks=\(self.currentTasks.count)")
        }
        for task in currentTasks.values {
            task.cancel()
        }
        currentTasks.removeAll()
        if let conversationID = conversations.selectedConversationID {
            pendingTurnStarts.remove(conversationID)
            agentLoop.cancelTurn(in: conversationID)
            handleAgentLoopEvent(.cancelled(conversationID: conversationID, turnID: agentLoop.currentTurnID(for: conversationID)))
        }
        isSending = false
    }

    // MARK: - Resume

    public func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentLoopOutcome {
        isSending = true
        notify(.started(conversationID: conversationID))
        defer { isSending = false }
        if Self.verbose {
            Self.logger.info("\(self.t)resume turn: conversation=\(conversationID.uuidString.prefix(8))")
        }
        do {
            let outcome = try await agentLoop.resumeTurn(in: conversationID, request: request)
            notify(.turnCompleted(conversationID: conversationID, outcome: outcome))
            return outcome
        } catch {
            notify(.turnFailed(conversationID: conversationID, reason: error.localizedDescription))
            throw error
        }
    }

    // MARK: - Private

    private func isSending(for conversationID: UUID) -> Bool {
        currentTasks[conversationID] != nil || pendingTurnStarts.contains(conversationID)
    }

    /// 由 MessageSenderPlugin 在 onBoot 中注册的 AgentLoop 监听器调用。
    public func handleAgentLoopEvent(_ event: AgentLoopEvent) {
        let conversationID: UUID
        let outcome: AgentLoopOutcome
        switch event {
        case .completed(let id, _):
            conversationID = id
            outcome = .completed
            notify(.turnCompleted(conversationID: id, outcome: outcome))
        case .suspended(let id, _, let suspension):
            conversationID = id
            outcome = .suspended(suspension.suspensionID)
            notify(.turnCompleted(conversationID: id, outcome: outcome))
        case .cancelled(let id, _):
            conversationID = id
            outcome = .cancelled
            notify(.turnCompleted(conversationID: id, outcome: outcome))
        case .failed(let id, _, let reason):
            conversationID = id
            outcome = .failed(reason)
            notify(.turnFailed(conversationID: id, reason: reason))
        case .started, .toolCallsReceived, .llmResponseReceived:
            return
        }

        let continuations = pendingOutcomes.removeValue(forKey: conversationID) ?? []
        if continuations.isEmpty {
            completedOutcomes[conversationID] = outcome
        }
        for continuation in continuations {
            continuation.resume(returning: outcome)
        }
    }

    private func waitForAgentLoop(in conversationID: UUID) async -> AgentLoopOutcome {
        if let outcome = completedOutcomes.removeValue(forKey: conversationID) {
            return outcome
        }
        return await withCheckedContinuation { continuation in
            pendingOutcomes[conversationID, default: []].append(continuation)
        }
    }

    /// 清空已随消息送出的附件挂起池（仅当池未被用户在等待期间修改过）。
    private func clearSentAttachments(
        _ sentImages: [UserImageAttachment],
        _ sentFiles: [UserFileAttachment]
    ) {
        if pendingImageAttachments == sentImages {
            clearImageAttachments()
        }
        if pendingFileAttachments == sentFiles {
            clearFileAttachments()
        }
    }

    /// 执行一个回合（发送路径与队列消费共用）。
    private func executeTurn(conversationID: UUID, userMessageID: UUID) async {
        isSending = true
        notify(.started(conversationID: conversationID))
        if Self.verbose {
            Self.logger.info("\(self.t)turn started: conversation=\(conversationID.uuidString.prefix(8)), userMessage=\(userMessageID.uuidString.prefix(8))")
        }
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isSending = false
                self.currentTasks.removeValue(forKey: conversationID)
                // 队列消费：当前回合结束后发下一条。
                self.drainPendingQueue(conversationID: conversationID)
            }
            do {
                try Task.checkCancellation()
                _ = await self.waitForAgentLoop(in: conversationID)
                if Self.verbose {
                    Self.logger.info("\(Self.t)turn completed: conversation=\(conversationID.uuidString.prefix(8))")
                }
            } catch {
                if Self.verbose {
                    Self.logger.error("\(Self.t)turn failed: conversation=\(conversationID.uuidString.prefix(8)), error=\(error.localizedDescription)")
                }
                let errorMessage = Message(
                    conversationID: conversationID,
                    role: .error,
                    content: error.localizedDescription
                )
                self.messages.insertMessage(errorMessage, to: conversationID)
                self.notify(.turnFailed(conversationID: conversationID, reason: error.localizedDescription))
            }
        }
        currentTasks[conversationID] = task
        await task.value
    }

    /// 依次发送待发队列（同一会话串行）。
    private func drainPendingQueue(conversationID: UUID) {
        guard var queue = pendingQueues[conversationID], !queue.isEmpty else {
            pendingQueues.removeValue(forKey: conversationID)
            return
        }
        let next = queue.removeFirst()
        if queue.isEmpty {
            pendingQueues.removeValue(forKey: conversationID)
        } else {
            pendingQueues[conversationID] = queue
        }

        var metadata: [String: String] = [:]
        metadata.merge(UserAttachmentMetadata.encodeImageAttachments(next.imageAttachments)) { _, new in new }
        metadata.merge(UserAttachmentMetadata.encodeFileAttachments(next.fileAttachments)) { _, new in new }
        let userMessage = Message(
            conversationID: conversationID,
            role: .user,
            content: next.content,
            metadata: metadata
        )
        completedOutcomes.removeValue(forKey: conversationID)
        messages.insertMessage(userMessage, to: conversationID)
        if Self.verbose {
            Self.logger.info("\(self.t)drain queue: sending next message, conversation=\(conversationID.uuidString.prefix(8)), message=\(userMessage.id.uuidString.prefix(8))")
        }
        Task { @MainActor [weak self] in
            await self?.executeTurn(conversationID: conversationID, userMessageID: userMessage.id)
        }
    }
}

// MARK: - Sending State Observer Handle

/// 发送状态观察者令牌：弱引用 owner，释放或 cancel 后自动停止接收。
@MainActor
private final class SendingStateObserverHandleImpl: SendingStateObserverHandle {
    private weak var owner: MessageSender?
    private let callback: (Bool) -> Void
    private var isCancelled = false

    init(owner: MessageSender, callback: @escaping (Bool) -> Void) {
        self.owner = owner
        self.callback = callback
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        owner?.removeSendingStateObserver(self)
    }

    fileprivate func invoke(_ isSending: Bool) {
        guard !isCancelled else { return }
        callback(isSending)
    }
}

/// 弱引用包装，令牌释放后自动失效。
@MainActor
private final class WeakSendingStateObserver {
    fileprivate weak var handle: SendingStateObserverHandleImpl?
    init(_ handle: SendingStateObserverHandleImpl) { self.handle = handle }
}
