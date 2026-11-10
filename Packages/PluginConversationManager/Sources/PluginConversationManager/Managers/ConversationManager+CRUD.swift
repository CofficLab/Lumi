import Foundation
import KitLLM
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
            modelID: legacyModelID(providerID: providerID, modelName: modelName)
        )
    }

    public func createConversation(
        title: String?,
        projectPath: String?,
        providerID: String?,
        modelName: String?,
        parentConversationID: UUID?
    ) throws -> UUID {
        try createConversation(
            title: title,
            projectPath: projectPath,
            modelID: legacyModelID(providerID: providerID, modelName: modelName),
            parentConversationID: parentConversationID
        )
    }

    public func createConversation(title: String?, projectPath: String?, modelID: String?) throws -> UUID {
        try createConversation(
            title: title,
            projectPath: projectPath,
            modelID: modelID,
            parentConversationID: nil
        )
    }

    public func createConversation(
        title: String?,
        binding: ProjectBinding,
        providerID: String?,
        modelName: String?
    ) throws -> UUID {
        try createConversation(
            title: title,
            binding: binding,
            modelID: legacyModelID(providerID: providerID, modelName: modelName),
            parentConversationID: nil
        )
    }

    public func createConversation(
        title: String?,
        binding: ProjectBinding,
        providerID: String?,
        modelName: String?,
        parentConversationID: UUID?
    ) throws -> UUID {
        try createConversation(
            title: title,
            binding: binding,
            modelID: legacyModelID(providerID: providerID, modelName: modelName),
            parentConversationID: parentConversationID
        )
    }

    public func createConversation(
        title: String?,
        projectPath: String?,
        modelID: String?,
        parentConversationID: UUID?
    ) throws -> UUID {
        // 旧接口的 nil 语义是「沿用当前项目」，这里显式映射，
        // 真正的落库解析统一走 ProjectBinding。
        try createConversation(
            title: title,
            binding: projectPath.map(ProjectBinding.project) ?? .inheritCurrent,
            modelID: modelID,
            parentConversationID: parentConversationID
        )
    }

    public func createConversation(
        title: String?,
        binding: ProjectBinding,
        modelID: String?,
        parentConversationID: UUID?
    ) throws -> UUID {
        let draft = makeConversationDraft(
            title: title,
            binding: binding,
            modelID: modelID,
            parentConversationID: parentConversationID
        )

        // Add to the bounded in-memory cache immediately.
        if draft.parentConversationID == nil {
            cache(draft.summary)
            selectedConversationID = draft.id
            updateCurrentTitle()
            persistSelectedConversationID()
            notifySelectedConversationChanged()
            notifyConversationObservers(.created(draft.id))
        }

        // Persist first, then notify the list. Otherwise the list may query the
        // database before this conversation is stored and conclude that nothing
        // changed.
        Task {
            do {
                try await persist(draft)
                self.notifyConversationsChanged()
            } catch {
                if Self.verbose {
                    Self.logger.error("\(Self.t)Failed to persist conversation: \(error)")
                }
            }
        }

        return draft.id
    }

    /// 创建对话并等待落库完成；持久化失败直接抛错。
    ///
    /// 与同步版本不同：先落库、后进入内存缓存。这样失败时不会留下一条
    /// 「只在内存里可见、重启就消失」的会话，调用方也能收到真实错误。
    public func createConversationAndWait(
        title: String?,
        projectPath: String?,
        modelID: String?,
        parentConversationID: UUID?
    ) async throws -> UUID {
        let draft = makeConversationDraft(
            title: title,
            binding: projectPath.map(ProjectBinding.project) ?? .inheritCurrent,
            modelID: modelID,
            parentConversationID: parentConversationID
        )

        guard store != nil else {
            // 没有持久化层：与其它轻量实现保持一致，直接走内存缓存。
            if draft.parentConversationID == nil {
                cache(draft.summary)
                selectedConversationID = draft.id
                updateCurrentTitle()
                persistSelectedConversationID()
                notifySelectedConversationChanged()
                notifyConversationObservers(.created(draft.id))
            }
            return draft.id
        }

        try await persist(draft)

        if draft.parentConversationID == nil {
            cache(draft.summary)
            selectedConversationID = draft.id
            updateCurrentTitle()
            persistSelectedConversationID()
            notifySelectedConversationChanged()
            notifyConversationObservers(.created(draft.id))
        }
        notifyConversationsChanged()

        if Self.verbose {
            Self.logger.info("\(Self.t)Created conversation \(draft.id.uuidString.prefix(8))... (waited for persistence)")
        }
        return draft.id
    }

    /// 创建对话所需的全部已解析字段，供同步/异步两条创建路径共用。
    private struct ConversationDraft {
        let id: UUID
        let title: String?
        let createdAt: Date
        let projectPath: String?
        let modelID: String?
        let verbosity: ResponseVerbosity
        let reasoningEffort: ReasoningEffort?
        let automationLevel: AutomationLevel
        let language: ConversationLanguage
        let parentConversationID: UUID?

        var summary: ConversationSummary {
            ConversationSummary(
                id: id,
                title: title,
                preview: "",
                createdAt: createdAt,
                updatedAt: createdAt,
                verbosity: verbosity,
                reasoningEffort: reasoningEffort,
                language: language,
                automationLevel: automationLevel,
                modelID: modelID,
                projectPath: projectPath,
                parentConversationID: parentConversationID
            )
        }
    }

    private func makeConversationDraft(
        title: String?,
        binding: ProjectBinding,
        modelID: String?,
        parentConversationID: UUID?
    ) -> ConversationDraft {
        let conversationTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTitle = conversationTitle?.isEmpty == true ? nil : conversationTitle

        // `.inheritCurrent` 才回退当前项目；`.none` 明确不绑定。
        let effectiveProjectPath = binding.resolvedProjectPath(
            inheriting: project?.currentProject?.path
        )
        let effectiveModelID = modelID.flatMap { LLMModelID(rawValue: $0)?.rawValue }
            ?? llmProviderManager?.selectedModelID?.rawValue

        if Self.verbose {
            Self.logger.info("\(Self.t)创建对话：\(normalizedTitle ?? "nil"), 项目：\(effectiveProjectPath ?? "nil"), 模型 ID：\(effectiveModelID ?? "nil"), 详细程度：\(self.globalVerbosity.rawValue)")
        }

        return ConversationDraft(
            id: UUID(),
            title: normalizedTitle,
            createdAt: Date(),
            projectPath: effectiveProjectPath,
            modelID: effectiveModelID,
            verbosity: globalVerbosity,
            reasoningEffort: globalReasoningEffort,
            automationLevel: globalAutomationLevel,
            language: language(for: selectedConversationID),
            parentConversationID: parentConversationID
        )
    }

    /// 落库并广播创建事件；失败时原样抛出。
    private func persist(_ draft: ConversationDraft) async throws {
        try await store?.createConversation(
            id: draft.id,
            title: draft.title,
            preview: "",
            createdAt: draft.createdAt,
            verbosity: draft.verbosity,
            modelID: draft.modelID,
            projectPath: draft.projectPath,
            parentConversationID: draft.parentConversationID,
            reasoningEffort: draft.reasoningEffort,
            automationLevel: draft.automationLevel
        )
        eventBus?.publishAsLegacy(
            ConversationDidCreateEvent(conversationID: draft.id),
            notificationName: .lumiConversationDidCreate,
            userInfo: ["conversationID": draft.id]
        )
    }

    private func legacyModelID(providerID: String?, modelName: String?) -> String? {
        if let providerID {
            if let modelName,
               let modelID = llmProviderManager?.modelID(providerID: providerID, model: modelName) {
                return modelID.rawValue
            }
            if let modelName {
                return LLMModelID(providerID: providerID, modelID: modelName)?.rawValue
            }
            return llmProviderManager?.modelID(providerID: providerID, model: nil)?.rawValue
        }

        if let modelName, let selectedProviderID = llmProviderManager?.selectedProviderID {
            return llmProviderManager?.modelID(providerID: selectedProviderID, model: modelName)?.rawValue
                ?? LLMModelID(providerID: selectedProviderID, modelID: modelName)?.rawValue
        }
        return llmProviderManager?.selectedModelID?.rawValue
    }

    public func selectConversation(id: UUID) {
        if Self.verbose {
            Self.logger.info("\(Self.t)Selecting conversation \(id.uuidString.prefix(8))...")
        }
        selectedConversationID = id
        updateCurrentTitle()
        persistSelectedConversationID()
        notifySelectedConversationChanged()
        backfillConversationIfNeeded(id: id)
    }

    /// 选中分页加载出的会话时，缓存里可能还没有它的摘要。
    /// 按 ID 从 Store 补载后再刷新标题，避免 `currentTitle` 退化成
    /// "No conversation"（issue #965）。
    ///
    /// 走 `cacheHydratedSummary` 而不是裸 `cache`：补载也会带来真实的
    /// 详细程度，UI 必须收到 `.verbosityChanged` 才能从缺省值纠正（issue #1069）。
    private func backfillConversationIfNeeded(id: UUID) {
        guard !conversations.contains(where: { $0.id == id }), let store else { return }
        Task { @MainActor [weak self] in
            guard let summary = await store.fetchConversation(id: id) else { return }
            guard let self, self.selectedConversationID == id else { return }
            self.cacheHydratedSummary(summary)
            self.updateCurrentTitle()
            self.notifyConversationObservers(.updated(id))
        }
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
        guard (replacement as AnyObject) !== self else { return }
        selectedConversationObservers.removeAll { $0.handle == nil }
        conversationObservers.removeAll { $0.handle == nil }

        for handle in selectedConversationObservers.compactMap(\.handle) {
            handle.transfer(to: replacement)
        }
        for handle in conversationObservers.compactMap(\.handle) {
            handle.transfer(to: replacement)
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
    /// - 内存：立即更新缓存中的 `lastMessageAt` 和 `updatedAt`，让当前状态可读；
    ///   对话列表的广播播报经过短暂去抖，避免发送期间频繁重载和重排侧栏；
    /// - 持久化：异步写入数据库，保证重启后排序一致。
    public func markConversationActive(id: UUID, messageDate: Date) {
        if let index = conversations.firstIndex(where: { $0.id == id }) {
            conversations[index].lastMessageAt = messageDate
            conversations[index].updatedAt = Date()
            scheduleConversationsChangedNotification()
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

        // 不再要求缓存命中：分页展示的历史会话可能不在内存窗口里，
        // 但删除必须以持久化记录为准（issue #965）。
        conversations.removeAll { $0.id == id }
        languageOverrides[id] = nil
        reasoningEffortOverrides[id] = nil
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
                // 子会话随父会话一起落库删除，也要通知观察者清理各自的数据
                // （例如 GoalTask 的 goals.sqlite）。根会话已在上面同步通知过。
                if conversationID != id {
                    notifyConversationObservers(.deleted(conversationID))
                }
            }
            _ = await store?.deleteConversations(ids: ids)
            self.notifyConversationsChanged()
        }
    }

    /// 批量删除「创建于 `cutoff` 之前」的对话。
    ///
    /// 清理链路与单条删除一致：取消回合、清消息、删工具调用、删库行。
    /// 与单条删除不同，这里是**同步等待**完成的——调用方（清理入口）需要
    /// 立刻知道删掉了多少条，才能给出准确反馈。
    @discardableResult
    public func deleteConversations(
        createdBefore cutoff: Date,
        projectPath: String?,
        includingChildConversations: Bool
    ) async -> [UUID] {
        let ids = await store?.conversationIDs(
            createdBefore: cutoff,
            projectPath: projectPath,
            includingChildConversations: includingChildConversations
        ) ?? []
        guard !ids.isEmpty else { return [] }

        // 连带删除子 Agent 会话：父对话被删时，它的子会话也是孤儿。
        var allIDs = Set(ids)
        for id in ids {
            let descendants = await store?.conversationIDsToDelete(id: id) ?? [id]
            allIDs.formUnion(descendants)
        }

        for conversationID in allIDs {
            agentTurn?.cancelTurn(in: conversationID)
            messageManager?.clearMessages(in: conversationID)
            await toolManager?.deleteToolCalls(for: conversationID)
        }
        _ = await store?.deleteConversations(ids: Array(allIDs))

        // 同步内存缓存，保证列表与徽标立即反映清理结果。
        conversations.removeAll { allIDs.contains($0.id) }
        if let selectedConversationID, allIDs.contains(selectedConversationID) {
            self.selectedConversationID = conversations.first?.id
            updateCurrentTitle()
            persistSelectedConversationID()
            notifySelectedConversationChanged()
        }

        for id in allIDs {
            languageOverrides[id] = nil
            reasoningEffortOverrides[id] = nil
            notifyConversationObservers(.deleted(id))
        }
        notifyConversationsChanged()

        if Self.verbose {
            Self.logger.info("\(Self.t)批量删除 \(allIDs.count) 个过期对话")
        }
        // 返回值必须与查询口径一致：只报告命中的顶层会话，连带删除的子
        // Agent 会话不能计入，否则「清理前 N 条」与「已删除 M 条」对不上（#897）。
        return ids
    }

    public func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedTitle = normalized.isEmpty ? nil : normalized
        // 缓存外的会话也要能改名：写盘以 ID 为准，内存只在命中时同步。
        guard conversations.contains(where: { $0.id == conversationID }) || store != nil else {
            return false
        }
        applyTitleChange(storedTitle, for: conversationID)

        // 持久化到数据库（异步）
        Task {
            await store?.updateTitle(id: conversationID, title: normalized)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)updateConversationTitle: conversation=\(conversationID.uuidString.prefix(8)), title=\(storedTitle ?? "nil")")
        }
        return true
    }

    /// 更新标题并等待落盘，只有数据库确认保存成功才发布内存与 UI 变化。
    ///
    /// 先落盘再改内存：保存失败时内存、Header 和列表都保持旧标题，不会出现
    /// 「界面显示新标题、重启后恢复旧标题」的假成功（issue #950）。
    public func updateConversationTitleAndWait(_ title: String, for conversationID: UUID) async -> Bool {
        guard let store else {
            return updateConversationTitle(title, for: conversationID)
        }

        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedTitle = normalized.isEmpty ? nil : normalized
        guard await store.updateTitle(id: conversationID, title: normalized) else {
            Self.logger.error("\(Self.t)updateConversationTitleAndWait: failed to persist title for conversation=\(conversationID.uuidString.prefix(8))")
            return false
        }
        applyTitleChange(storedTitle, for: conversationID)

        if Self.verbose {
            Self.logger.info("\(Self.t)updateConversationTitleAndWait: conversation=\(conversationID.uuidString.prefix(8)), title=\(storedTitle ?? "nil")")
        }
        return true
    }

    /// 同步内存标题并通知 UI；缓存未命中时只发通知（写盘按 ID 进行）。
    private func applyTitleChange(_ storedTitle: String?, for conversationID: UUID) {
        if let index = conversations.firstIndex(where: { $0.id == conversationID }) {
            conversations[index].title = storedTitle
        }
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
    }

    public func isSending(for conversationID: UUID?) -> Bool {
        // TODO: Implement based on actual sending state
        return false
    }
}
