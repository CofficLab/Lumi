import Foundation
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderMessageSender

/// 插件自带的 `MessageSendingProviding` 实现（不复用 `ProviderMessageSender.DefaultMessageSender`）。
///
/// 独立复刻旧版 `MessageSender` 的完整职责，行为与默认实现对齐：
/// 1. 发送前 trim，空白直接返回；
/// 2. 解析目标会话（显式 id > 选中会话 > 自动创建新会话）并置为当前时间线；
/// 3. 图片/文件附件挂起池随下一条消息一起送出，编码进 `Message.metadata`；
/// 4. 同一会话发送中时新消息进入 pending 队列，当前回合结束后依次发出；
/// 5. 落库 user 消息后交给 AgentLoop 执行完整回合（流式 + 工具 + 授权挂起）；
/// 6. 回合失败时落库 error 消息；
/// 7. `cancelCurrentRequest` 取消当前回合；`resumeTurn` 恢复被挂起的回合。
///
/// 插件自行持有实现，宿主可通过替换本插件列表定制消息发送行为。
@MainActor
public final class LumiMessageSender: MessageSendingProviding {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin-message-sender",
        category: "MessageSender"
    )

    private let conversations: any ConversationManaging
    private let messages: any MessageManaging
    private let agentLoop: any AgentLoopProviding
    private var currentTasks: [UUID: Task<Void, Never>] = [:]

    @Published public private(set) var isSending = false
    @Published public private(set) var pendingImageAttachments: [UserImageAttachment] = []
    @Published public private(set) var pendingFileAttachments: [UserFileAttachment] = []
    @Published public private(set) var pendingQueues: [UUID: [PendingChatMessage]] = [:]

    public init(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        agentLoop: any AgentLoopProviding
    ) {
        self.conversations = conversations
        self.messages = messages
        self.agentLoop = agentLoop
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
        try await sendMessage(
            content,
            imageAttachments: pendingImageAttachments,
            fileAttachments: pendingFileAttachments,
            conversationID: conversationID
        )
    }

    public func sendMessage(
        _ content: String,
        imageAttachments: [UserImageAttachment],
        fileAttachments: [UserFileAttachment],
        conversationID: UUID?
    ) async throws {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            Self.logger.debug("sendMessage ignored: empty content after trim")
            return
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
            Self.logger.info("created new conversation \(targetID.uuidString) for send")
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
            Self.logger.info("send queued: conversation=\(targetID.uuidString.prefix(8)), queueDepth=\(self.pendingQueues[targetID]?.count ?? 0)")
            return
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
        messages.insertMessage(userMessage, to: targetID)
        clearSentAttachments(imageAttachments, fileAttachments)
        Self.logger.info("send user message: conversation=\(targetID.uuidString.prefix(8)), message=\(userMessage.id.uuidString.prefix(8)), contentChars=\(trimmed.count), images=\(imageAttachments.count), files=\(fileAttachments.count)")

        await executeTurn(conversationID: targetID, userMessageID: userMessage.id)
    }

    public func cancelCurrentRequest() {
        Self.logger.info("cancel current request: activeTasks=\(self.currentTasks.count)")
        for task in currentTasks.values {
            task.cancel()
        }
        currentTasks.removeAll()
        if let conversationID = conversations.selectedConversationID {
            agentLoop.cancelTurn(in: conversationID)
        }
        isSending = false
    }

    // MARK: - Resume

    public func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentLoopOutcome {
        isSending = true
        defer { isSending = false }
        Self.logger.info("resume turn: conversation=\(conversationID.uuidString.prefix(8))")
        return try await agentLoop.resumeTurn(in: conversationID, request: request)
    }

    // MARK: - Private

    private func isSending(for conversationID: UUID) -> Bool {
        currentTasks[conversationID] != nil
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
        Self.logger.info("turn started: conversation=\(conversationID.uuidString.prefix(8)), userMessage=\(userMessageID.uuidString.prefix(8))")
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isSending = false
                self.currentTasks.removeValue(forKey: conversationID)
                // 队列消费：当前回合结束后发下一条。
                self.drainPendingQueue(conversationID: conversationID)
            }
            do {
                _ = try await self.agentLoop.runTurn(in: conversationID)
                Self.logger.info("turn completed: conversation=\(conversationID.uuidString.prefix(8))")
            } catch {
                Self.logger.error("turn failed: conversation=\(conversationID.uuidString.prefix(8)), error=\(error.localizedDescription)")
                let errorMessage = Message(
                    conversationID: conversationID,
                    role: .error,
                    content: error.localizedDescription
                )
                self.messages.insertMessage(errorMessage, to: conversationID)
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
        messages.insertMessage(userMessage, to: conversationID)
        Self.logger.info("drain queue: sending next message, conversation=\(conversationID.uuidString.prefix(8)), message=\(userMessage.id.uuidString.prefix(8))")
        Task { @MainActor [weak self] in
            await self?.executeTurn(conversationID: conversationID, userMessageID: userMessage.id)
        }
    }
}
