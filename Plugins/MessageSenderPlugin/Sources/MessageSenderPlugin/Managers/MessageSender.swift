import Foundation
import LumiKernel
import os
import SuperLogKit

/// Default implementation of `MessageSending`.
///
/// Responsibilities (per `MessageSending` contract):
/// 1. Trim `content`; return early on empty input.
/// 2. Resolve the target conversation:
///    - `conversationID` if non-nil,
///    - else `kernel.conversations?.selectedConversationID`,
///    - else throw `LumiKernelError.noActiveConversation`.
/// 3. Insert a `LumiChatMessage(role: .user, ...)` via
///    `kernel.messageManager?.insertMessage(_:to:)`.
/// 4. Hand the full conversation history to the first registered
///    LLM provider via `kernel.llmProvider?.sendToFirstProvider(_:)`,
///    using that provider's `defaultModel` for the request. Insert
///    the returned assistant message back into the message history.
///
/// `isSending` is tracked per conversation, so one chat can be sending while
/// another stays idle. The active conversation IDs are stored in-memory and
/// bridged through `objectWillChange` via `@Published`.
@MainActor
public final class MessageSender: MessageSending, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-send-manager.service")
    public nonisolated static let emoji = "📤"
    nonisolated static let verbose = true

    @Published private var sendingConversationIDs: Set<UUID> = []
    @Published private var pendingMessageQueues: [UUID: [LumiPendingMessage]] = [:]
    private var pendingContinuationConversationIDs: Set<UUID> = []

    public var isSending: Bool {
        !sendingConversationIDs.isEmpty
    }

    /// 当前挂起、等待下次发送时随消息一起送出的图片附件。
    /// `addAttachment / removeAttachment / clearAttachments` 维护此集合。
    @Published public private(set) var pendingAttachments: [LumiImageAttachment] = []

    /// 当前挂起、等待下次发送时随消息一起送出的**文件**附件(与图片并行的链路)。
    /// `addFileAttachment / removeFileAttachment / clearFileAttachments` 维护此集合。
    @Published public private(set) var pendingFileAttachments: [LumiFileAttachment] = []

    private weak var kernel: LumiKernel?
    private var resendObserver: NotificationObserverToken?

    public init(kernel: LumiKernel) {
        self.kernel = kernel
        installResendObserver()
    }

    deinit {
        if let resendObserver {
            NotificationCenter.default.removeObserver(resendObserver.value)
        }
    }

    public func isSending(for conversationID: UUID?) -> Bool {
        guard let conversationID else {
            return isSending
        }
        return sendingConversationIDs.contains(conversationID)
    }

    public func currentStatusRow(for conversationID: UUID) -> LumiChatMessage? {
        guard isSending(for: conversationID) else { return nil }
        let streaming = kernel?.messageStreaming
        return LumiChatMessage(
            id: LumiStatusRowID,
            conversationID: conversationID,
            role: .status,
            content: statusContent(
                stage: streaming?.currentStage ?? .idle,
                thinking: streaming?.currentStreamingRow?.reasoningContent
            ),
            metadata: ["isTransientStatus": "true"]
        )
    }

    /// 把当前阶段映射成用户可见的状态文案。
    ///
    /// 阶段来自 `MessageStreaming`（由 runner 在流式生命周期中维护）。
    /// - `thinking` 阶段：展示实际的思考文本（实时滚动），让用户看到模型推理过程；
    /// - 其余阶段用固定文案。
    /// 工具调用回合间隔阶段归到 `.sending`（"正在发送消息…"）——
    /// 因为 onChunk 不推送 tool-call 增量，store 此时回到空态，无法精确区分。
    private func statusContent(stage: ChatStage, thinking: String?) -> String {
        switch stage {
        case .idle, .sending:
            String(localized: "status.sending", defaultValue: "正在发送消息…")
        case .thinking:
            // 思考阶段直接展示思考文本;尚未收到任何思考增量时回退到固定文案。
            if let thinking, !thinking.isEmpty {
                thinking
            } else {
                String(localized: "status.thinking", defaultValue: "正在思考…")
            }
        case .generating:
            String(localized: "status.generating", defaultValue: "正在生成回复…")
        }
    }

    public func pendingMessages(for conversationID: UUID) -> [LumiPendingMessage] {
        pendingMessageQueues[conversationID] ?? []
    }

    public func cancelPendingMessage(id: UUID, in conversationID: UUID) {
        guard var queue = pendingMessageQueues[conversationID] else { return }
        queue.removeAll { $0.id == id }
        if queue.isEmpty {
            pendingMessageQueues.removeValue(forKey: conversationID)
        } else {
            pendingMessageQueues[conversationID] = queue
        }
    }

    // MARK: - 附件挂起池

    /// 添加附件。幂等:同 `id` 已存在则忽略。
    public func addAttachment(_ attachment: LumiImageAttachment) {
        guard !pendingAttachments.contains(where: { $0.id == attachment.id }) else {
            if Self.verbose {
                Self.logger.info("\(Self.t)addAttachment ➡️ id=\(attachment.id.uuidString.prefix(8))… 已存在,忽略")
            }
            return
        }
        pendingAttachments.append(attachment)
        if Self.verbose {
            Self.logger.info("\(Self.t)addAttachment ➡️ id=\(attachment.id.uuidString.prefix(8))…, mime=\(attachment.mimeType), pool.size=\(self.pendingAttachments.count)")
        }
    }

    /// 按 id 移除挂起附件。id 不存在则 no-op。
    public func removeAttachment(id: UUID) {
        let before = pendingAttachments.count
        pendingAttachments.removeAll { $0.id == id }
        if Self.verbose {
            Self.logger.info("\(Self.t)removeAttachment ➡️ id=\(id.uuidString.prefix(8))…, before=\(before), after=\(self.pendingAttachments.count)")
        }
    }

    /// 清空所有挂起附件。
    public func clearAttachments() {
        let count = pendingAttachments.count
        pendingAttachments.removeAll()
        if Self.verbose {
            Self.logger.info("\(Self.t)clearAttachments ➡️ cleared \(count) items")
        }
    }

    // MARK: - 文件附件挂起池

    /// 添加文件附件。幂等:同 `id` 已存在则忽略。
    public func addFileAttachment(_ attachment: LumiFileAttachment) {
        guard !pendingFileAttachments.contains(where: { $0.id == attachment.id }) else {
            if Self.verbose {
                Self.logger.info("\(Self.t)addFileAttachment ➡️ id=\(attachment.id.uuidString.prefix(8))… 已存在,忽略")
            }
            return
        }
        pendingFileAttachments.append(attachment)
        if Self.verbose {
            Self.logger.info("\(Self.t)addFileAttachment ➡️ id=\(attachment.id.uuidString.prefix(8))…, name=\(attachment.fileName), pool.size=\(self.pendingFileAttachments.count)")
        }
    }

    /// 按 id 移除挂起文件附件。id 不存在则 no-op。
    public func removeFileAttachment(id: UUID) {
        let before = pendingFileAttachments.count
        pendingFileAttachments.removeAll { $0.id == id }
        if Self.verbose {
            Self.logger.info("\(Self.t)removeFileAttachment ➡️ id=\(id.uuidString.prefix(8))…, before=\(before), after=\(self.pendingFileAttachments.count)")
        }
    }

    /// 清空所有挂起文件附件。
    public func clearFileAttachments() {
        let count = pendingFileAttachments.count
        pendingFileAttachments.removeAll()
        if Self.verbose {
            Self.logger.info("\(Self.t)clearFileAttachments ➡️ cleared \(count) items")
        }
    }

    // MARK: - 发送

    public func sendMessage(_ content: String, conversationID: UUID?) async throws {
        // 委托给带 attachments 的重载,使用当前挂起池快照。
        try await sendMessage(
            content,
            imageAttachments: pendingAttachments,
            conversationID: conversationID
        )
    }

    public func sendMessage(
        _ content: String,
        imageAttachments: [LumiImageAttachment],
        conversationID: UUID?
    ) async throws {
        try await sendMessage(
            content,
            imageAttachments: imageAttachments,
            fileAttachments: pendingFileAttachments,
            conversationID: conversationID
        )
    }

    private func sendMessage(
        _ content: String,
        imageAttachments: [LumiImageAttachment],
        fileAttachments: [LumiFileAttachment],
        conversationID: UUID?
    ) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)sendMessage 开始")
        }

        // 1. Trim & early-return on empty input
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if Self.verbose {
                Self.logger.info("\(Self.t)sendMessage ➡️ content 空白,直接返回")
            }
            return
        }

        // 2. Resolve target conversation
        let targetID: UUID
        if let conversationID {
            targetID = conversationID
        } else if let selected = kernel?.conversations?.selectedConversationID {
            targetID = selected
        } else {
            // No conversation selected - auto-create one with first message as title
            let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
            let maxLength = 40
            let truncatedTitle = firstLine.count > maxLength
                ? String(firstLine.prefix(maxLength)) + "..."
                : firstLine

            if Self.verbose {
                Self.logger.info("\(Self.t)解析目标会话 ➡️ 没有选中对话,自动创建新对话,标题=\"\(truncatedTitle)\"")
            }
            guard let newID = try? kernel?.conversations?.createConversation(title: truncatedTitle, projectPath: nil, providerID: nil, modelName: nil) else {
                Self.logger.error("\(Self.t)sendMessage 失败 ➡️ 创建对话失败")
                throw LumiKernelError.noActiveConversation
            }
            targetID = newID
        }

        let pendingMessage = LumiPendingMessage(
            conversationID: targetID,
            content: trimmed,
            imageAttachments: imageAttachments,
            fileAttachments: fileAttachments
        )
        if isSending(for: targetID) {
            pendingMessageQueues[targetID, default: []].append(pendingMessage)
            clearAttachments()
            clearFileAttachments()
            if Self.verbose {
                Self.logger.info("\(Self.t)消息进入待发送队列 ➡️ conversation=\(targetID.uuidString.prefix(8))…, queue.size=\(self.pendingMessageQueues[targetID]?.count ?? 0)")
            }
            return
        }

        // 3. Persist user message into the message history
        if Self.verbose {
            let hasLastMessage = self.kernel?.messageManager?.lastMessage(in: targetID) != nil
            Self.logger.info("\(Self.t)准备进入发送态 ➡️ target=\(targetID.uuidString.prefix(8))…, hasLastMessage=\(hasLastMessage)")
        }
        beginSending(in: targetID)
        if Self.verbose {
            Self.logger.info("\(Self.t)isSending -> true, 准备写入 user 消息到会话 \(targetID.uuidString.prefix(8))…, activeSendingConversations=\(self.sendingConversationIDs.count)")
        }

        // 把 attachments 序列化进 metadata["imageAttachments"] JSON(如有)
        var metadata: [String: String] = [:]
        if !imageAttachments.isEmpty {
            do {
                let data = try JSONEncoder().encode(imageAttachments)
                metadata["imageAttachments"] = String(data: data, encoding: .utf8) ?? ""
            } catch {
                if Self.verbose {
                    Self.logger.error("\(Self.t)sendMessage ➡️ 编码 attachments 失败: \(error.localizedDescription)")
                }
            }
        }

        // 把文件附件序列化进 metadata["fileAttachments"] JSON(如有)。
        // 文件链路与图片并行:取当前文件挂起池快照,文本类文件正文在下游注入用户消息。
        if !fileAttachments.isEmpty {
            metadata = LumiFileAttachmentMetadata.encode(fileAttachments, into: metadata)
        }

        let userMessage = LumiChatMessage(
            conversationID: targetID,
            role: .user,
            content: trimmed,
            metadata: metadata
        )
        if Self.verbose {
            Self.logger.info("\(Self.t)即将插入 user 消息 ➡️ id=\(userMessage.id.uuidString.prefix(8))…, target=\(targetID.uuidString.prefix(8))…, metadataKeys=\(metadata.keys.sorted().joined(separator: ","))")
        }
        kernel?.messageManager?.insertMessage(userMessage, to: targetID)

        defer {
            endSending(in: targetID)
            // Do not clear attachments added while an earlier turn was running;
            // those belong to a later queued/draft message.
            if pendingAttachments == imageAttachments {
                clearAttachments()
            }
            if pendingFileAttachments == fileAttachments {
                clearFileAttachments()
            }
            if Self.verbose {
                Self.logger.info("\(Self.t)isSending -> false, sendMessage 结束 ➡️ target=\(targetID.uuidString.prefix(8))…, activeSendingConversations=\(self.sendingConversationIDs.count)")
            }
        }

        // 4. Delegate to AgentTurnRunner to execute the full agent loop.
        guard let kernelInstance = kernel else {
            return
        }

        do {
            if Self.verbose {
                Self.logger.info("\(Self.t)🛫 准备调用 agentTurnManager.runTurn")
            }
            try await kernelInstance.agentTurnManager?.runTurn(in: targetID)
            if Self.verbose {
                Self.logger.info("\(Self.t)agentTurnManager.runTurn 完成")
            }
        } catch {
            Self.logger.error("\(Self.t)sendMessage ➡️ agentTurnManager 抛出 error target=\(targetID.uuidString.prefix(8))…: \(error.localizedDescription)")
            // Insert error message into conversation
            let errorMessage = LumiChatMessage(
                conversationID: targetID,
                role: .error,
                content: error.localizedDescription
            )
            kernelInstance.messageManager?.insertMessage(errorMessage, to: targetID)
            if Self.verbose {
                Self.logger.info("\(Self.t)error 消息已落库 ➡️ id=\(errorMessage.id.uuidString.prefix(8))…")
            }
        }
    }

    public func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentTurnOutcome {
        beginSending(in: conversationID)
        defer { endSending(in: conversationID) }

        guard let manager = kernel?.agentTurnManager else {
            throw AgentTurnManagingError.resumeNotSupported
        }
        return try await manager.resumeTurn(in: conversationID, request: request)
    }

    public func continueTurn(in conversationID: UUID) {
        guard !isSending(for: conversationID) else {
            pendingContinuationConversationIDs.insert(conversationID)
            return
        }

        startContinuation(in: conversationID)
    }

    public func cancelCurrentRequest() {
        if let conversationID = kernel?.conversations?.selectedConversationID, isSending(for: conversationID) {
            pendingContinuationConversationIDs.remove(conversationID)
            endSending(in: conversationID)
            // Cancel the agent turn if one is running
            kernel?.agentTurnManager?.cancelTurn(in: conversationID)
            if Self.verbose {
                Self.logger.info("\(Self.t)cancelCurrentRequest ➡️ conversation=\(conversationID.uuidString.prefix(8))…, turn cancelled, activeSendingConversations=\(self.sendingConversationIDs.count)")
            }
        } else if Self.verbose {
            Self.logger.info("\(Self.t)cancelCurrentRequest ➡️ 当前无 in-flight 发送, no-op")
        }
    }

    public func resendMessage(id: UUID, in conversationID: UUID) async {
        guard !isSending(for: conversationID) else {
            if Self.verbose {
                Self.logger.info("\(Self.t)resendMessage ignored because conversation is sending ➡️ conversation=\(conversationID.uuidString.prefix(8))…")
            }
            return
        }
        guard let original = kernel?.messageManager?.message(id: id, in: conversationID),
              original.role == .user else {
            if Self.verbose {
                Self.logger.info("\(Self.t)resendMessage could not find user message ➡️ conversation=\(conversationID.uuidString.prefix(8))…, message=\(id.uuidString.prefix(8))…")
            }
            return
        }

        let trimmed = original.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if Self.verbose {
                Self.logger.info("\(Self.t)resendMessage ignored empty user message ➡️ message=\(id.uuidString.prefix(8))…")
            }
            return
        }

        beginSending(in: conversationID)
        let resent = LumiChatMessage(
            conversationID: conversationID,
            role: .user,
            content: trimmed,
            metadata: original.metadata
        )
        kernel?.messageManager?.insertMessage(resent, to: conversationID)

        defer {
            endSending(in: conversationID)
        }

        await runAgentTurn(in: conversationID)
    }

    private func installResendObserver() {
        let observer = NotificationCenter.default.addObserver(
            forName: .lumiResendMessage,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let messageID = Self.uuidValue(
                notification.userInfo?[LumiMessageSavedNotification.messageIDKey]
            ),
                let conversationID = Self.uuidValue(
                    notification.userInfo?[LumiMessageSavedNotification.conversationIDKey]
                ) else {
                return
            }

            Task { @MainActor [weak self] in
                await self?.resendMessage(id: messageID, in: conversationID)
            }
        }
        resendObserver = NotificationObserverToken(value: observer)
    }

    private nonisolated static func uuidValue(_ value: Any?) -> UUID? {
        if let uuid = value as? UUID {
            return uuid
        }
        if let string = value as? String {
            return UUID(uuidString: string)
        }
        return nil
    }

    private func runAgentTurn(in conversationID: UUID) async {
        guard let kernelInstance = kernel else {
            return
        }

        do {
            try await kernelInstance.agentTurnManager?.runTurn(in: conversationID)
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)runAgentTurn 抛出 error target=\(conversationID.uuidString.prefix(8))…: \(error.localizedDescription)")
            }
            let errorMessage = LumiChatMessage(
                conversationID: conversationID,
                role: .error,
                content: error.localizedDescription
            )
            kernelInstance.messageManager?.insertMessage(errorMessage, to: conversationID)
        }
    }

    private func beginSending(in conversationID: UUID) {
        sendingConversationIDs.insert(conversationID)
    }

    private func endSending(in conversationID: UUID) {
        sendingConversationIDs.remove(conversationID)
        guard let next = dequeuePendingMessage(for: conversationID) else {
            guard pendingContinuationConversationIDs.remove(conversationID) != nil else { return }
            startContinuation(in: conversationID)
            return
        }
        startQueuedMessage(next)
    }

    private func dequeuePendingMessage(for conversationID: UUID) -> LumiPendingMessage? {
        guard var queue = pendingMessageQueues[conversationID], !queue.isEmpty else { return nil }
        let next = queue.removeFirst()
        if queue.isEmpty {
            pendingMessageQueues.removeValue(forKey: conversationID)
        } else {
            pendingMessageQueues[conversationID] = queue
        }
        return next
    }

    private func startQueuedMessage(_ message: LumiPendingMessage) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await sendMessage(
                    message.content,
                    imageAttachments: message.imageAttachments,
                    fileAttachments: message.fileAttachments,
                    conversationID: message.conversationID
                )
            } catch {
                if Self.verbose {
                    Self.logger.error("\(Self.t)消费待发送消息失败 ➡️ conversation=\(message.conversationID.uuidString.prefix(8))…: \(error.localizedDescription)")
                }
            }
        }
    }

    private func startContinuation(in conversationID: UUID) {
        beginSending(in: conversationID)
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { endSending(in: conversationID) }
            await runAgentTurn(in: conversationID)
        }
    }
}

private final class NotificationObserverToken: @unchecked Sendable {
    let value: NSObjectProtocol

    init(value: NSObjectProtocol) {
        self.value = value
    }
}
