import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage

/// 默认消息发送实现（KernelCore 体系，复刻旧版 `MessageSender`）。
///
/// 职责：
/// 1. 发送前 trim，空白直接返回；
/// 2. 解析目标会话（显式 id > 选中会话 > 自动创建新会话）；
/// 3. 图片/文件附件挂起池随下一条消息一起送出，编码进 `metadata`；
/// 4. 同一会话发送中时新消息进入 pending 队列，当前回合结束后依次发出；
/// 5. 落库 user 消息后交给 AgentLoop 执行完整回合（流式 + 工具 + 授权挂起）；
/// 6. 回合失败时落库 error 消息。
@MainActor
public final class DefaultMessageSendingProviding: MessageSendingProviding {
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

    // MARK: - Attachments

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
        guard !trimmed.isEmpty else { return }

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

        await executeTurn(conversationID: targetID, userMessageID: userMessage.id)
    }

    public func cancelCurrentRequest() {
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
            } catch {
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
        Task { @MainActor [weak self] in
            await self?.executeTurn(conversationID: conversationID, userMessageID: userMessage.id)
        }
    }
}
