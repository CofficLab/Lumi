import Foundation
import KernelCore
import ProviderAgentLoop
import ProviderConversation
import ProviderLLMManager
import ProviderMessage
import ProviderToolManager

extension ConversationManager {
    // MARK: - CRUD

    public func createConversation(title: String?, projectPath: String?, providerID: String?, modelName: String?) throws -> UUID {
        try createConversation(
            title: title,
            projectPath: projectPath,
            providerID: providerID,
            modelName: modelName,
            parentConversationID: nil
        )
    }

    public func createConversation(
        title: String?,
        projectPath: String?,
        providerID: String?,
        modelName: String?,
        parentConversationID: UUID?
    ) throws -> UUID {
        let now = Date()
        let id = UUID()
        let conversationTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTitle = conversationTitle?.isEmpty == true ? nil : conversationTitle

        // 如果未指定 projectPath，则自动使用当前项目
        let effectiveProjectPath = projectPath ?? project?.currentProject?.path
        // 如果未指定 providerID，则自动使用当前选中的供应商
        let effectiveProviderID = providerID ?? llmProviderManager?.selectedProviderID
        // 如果未指定 modelName，则自动使用当前选中的模型
        let effectiveModelName = modelName ?? llmProviderManager?.selectedModel
        // 继承全局设置（详细程度、推理强度、对话模式）
        let effectiveVerbosity = self.globalVerbosity
        let effectiveReasoningEffort = self.globalReasoningEffort
        let effectiveAutomationLevel = self.globalAutomationLevel
        let effectiveLanguage = self.language(for: selectedConversationID)

        if Self.verbose {
            Self.logger.info("\(Self.t)创建对话：\(normalizedTitle ?? "nil"), 项目：\(effectiveProjectPath ?? "nil"), 供应商：\(effectiveProviderID ?? "nil"), 模型：\(effectiveModelName ?? "nil"), 详细程度：\(effectiveVerbosity.rawValue)")
        }

        let conversation = ConversationSummary(
            id: id,
            title: normalizedTitle,
            preview: "",
            createdAt: now,
            updatedAt: now,
            verbosity: effectiveVerbosity,
            reasoningEffort: effectiveReasoningEffort,
            language: effectiveLanguage,
            automationLevel: effectiveAutomationLevel,
            providerID: effectiveProviderID,
            modelName: effectiveModelName,
            projectPath: effectiveProjectPath,
            parentConversationID: parentConversationID
        )

        // Add to the bounded in-memory cache immediately.
        if parentConversationID == nil {
            cache(conversation)
            selectedConversationID = id
            updateCurrentTitle()
            persistSelectedConversationID()
            notifySelectedConversationChanged()
            notifyConversationObservers(.created(id))
        }

        // Persist first, then notify the list. Otherwise the list may query the
        // database before this conversation is stored and conclude that nothing
        // changed.
        Task {
            do {
                try await store?.createConversation(
                    id: id,
                    title: normalizedTitle,
                    preview: "",
                    createdAt: now,
                    providerID: effectiveProviderID,
                    modelName: effectiveModelName,
                    projectPath: effectiveProjectPath,
                    parentConversationID: parentConversationID,
                    reasoningEffort: effectiveReasoningEffort,
                    automationLevel: effectiveAutomationLevel
                )
                self.eventBus?.publishAsLegacy(
                    ConversationDidCreateEvent(conversationID: id),
                    notificationName: .lumiConversationDidCreate,
                    userInfo: ["conversationID": id]
                )
                self.notifyConversationsChanged()
            } catch {
                if Self.verbose {
                    Self.logger.error("\(Self.t)Failed to persist conversation: \(error)")
                }
            }
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)Created conversation \(id.uuidString.prefix(8))...")
        }

        return id
    }

    public func selectConversation(id: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)Selecting conversation \(id.uuidString.prefix(8))...")
        }
        selectedConversationID = id
        updateCurrentTitle()
        persistSelectedConversationID()
        notifySelectedConversationChanged()
    }

    /// 注册选中对话观察者：选中值实际变化时回调，令牌释放或 cancel 后自动停止。
    @discardableResult
    public func addSelectedConversationObserver(
        _ callback: @escaping (UUID?) -> Void
    ) -> any SelectedConversationObserverHandle {
        let handle = ConversationSelectedConversationObserverHandle(owner: self, callback: callback)
        selectedConversationObservers.append(WeakSelectedConversationObserver(handle))
        return handle
    }

    public func transferObservers(to replacement: any ConversationManaging) {
        selectedConversationObservers.removeAll { $0.handle == nil }
        conversationObservers.removeAll { $0.handle == nil }

        for callback in selectedConversationObservers.compactMap({ $0.handle?.callback }) {
            _ = replacement.addSelectedConversationObserver(callback)
        }
        for callback in conversationObservers.compactMap({ $0.handle?.callback }) {
            _ = replacement.addConversationObserver(callback)
        }
    }

    public func deselectConversation() {
        if Self.verbose {
            Self.logger.info("\(Self.t)Deselecting conversation")
        }
        selectedConversationID = nil
        updateCurrentTitle()
        persistSelectedConversationID()
        notifySelectedConversationChanged()
    }

    /// 标记对话为活跃：刷新 `lastMessageAt` 和 `updatedAt`，使其在对话列表排序中置顶。
    ///
    /// 由消息写入路径在会话收到新消息时调用(见 `MessageManager.insertMessage`)。
    /// - 内存：更新缓存中的 `lastMessageAt` 和 `updatedAt` 并广播 `conversationsDidChange`，
    ///   驱动对话列表(ConversationListPlugin)重新加载并按最新时间重排；
    /// - 持久化：异步写入数据库，保证重启后排序一致。
    public func markConversationActive(id: UUID, messageDate: Date) {
        if let index = conversations.firstIndex(where: { $0.id == id }) {
            conversations[index].lastMessageAt = messageDate
            conversations[index].updatedAt = Date()
            notifyConversationsChanged()
            notifyConversationObservers(.markedActive(id))
        }

        Task {
            _ = await store?.updateLastMessageAt(id: id, messageDate: messageDate)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)markConversationActive: conversation=\(id.uuidString.prefix(8))")
        }
    }

    public func deleteConversation(id: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)Deleting conversation \(id.uuidString.prefix(8))...")
        }

        guard conversations.contains(where: { $0.id == id }) else { return }
        conversations.removeAll { $0.id == id }
        notifyConversationObservers(.deleted(id))

        if selectedConversationID == id {
            selectedConversationID = conversations.first?.id
            updateCurrentTitle()
            persistSelectedConversationID()
            notifySelectedConversationChanged()
        }

        // Delete every storage owned by the conversation. The list is updated
        // optimistically, but the change notification is sent only after the
        // persistent cleanup so a reload cannot resurrect the row.
        Task {
            let ids = await store?.conversationIDsToDelete(id: id) ?? [id]
            for conversationID in ids {
                agentTurn?.cancelTurn(in: conversationID)
                messageManager?.clearMessages(in: conversationID)
                await toolManager?.deleteToolCalls(for: conversationID)
            }
            _ = await store?.deleteConversations(ids: ids)
            self.notifyConversationsChanged()
        }
    }

    public func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return false
        }
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedTitle = normalized.isEmpty ? nil : normalized
        conversations[index].title = storedTitle

        if conversationID == selectedConversationID {
            updateCurrentTitle()
        }
        notifyConversationsChanged()
        notifyConversationObservers(.updated(conversationID))
        eventBus?.publishAsLegacy(
            ConversationTitleDidChangeEvent(conversationID: conversationID),
            notificationName: .lumiConversationTitleDidChange,
            userInfo: ["conversationID": conversationID]
        )

        // 持久化到数据库（异步）
        Task {
            await store?.updateTitle(id: conversationID, title: normalized)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)updateConversationTitle: conversation=\(conversationID.uuidString.prefix(8)), title=\(storedTitle ?? "nil")")
        }
        return true
    }

    public func isSending(for conversationID: UUID?) -> Bool {
        // TODO: Implement based on actual sending state
        return false
    }
}
