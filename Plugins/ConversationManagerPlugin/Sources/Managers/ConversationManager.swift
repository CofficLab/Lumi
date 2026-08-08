import Combine
import Foundation
import LumiKernel
import SuperLogKit
import os

/// Conversation Manager - real implementation using SwiftData persistence
///
/// Uses in-memory array for sync access, persists to SQLite async via ConversationStore.
@MainActor
public final class ConversationManager: ObservableObject, ConversationManaging, SuperLog {
    private static let initialPageSize = 40
    /// 选中状态写盘队列：串行执行，保证连续切换会话时最后一次写入生效。
    nonisolated private static let stateWriteQueue = DispatchQueue(
        label: "com.coffic.lumi.conversation-manager.state-write",
        qos: .utility
    )
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-manager")
    nonisolated public static let emoji = "💬"
    public nonisolated static let verbose = false

    @Published public private(set) var conversations: [LumiConversationSummary] = []
    @Published public private(set) var selectedConversationID: UUID?
    @Published public private(set) var currentTitle: String = "No conversation"
    @Published public private(set) var isLoadingConversations = true
    @Published public private(set) var globalVerbosity: LumiResponseVerbosity = .defaultVerbosity

    /// Notification posted when conversations list changes
    static let conversationsDidChangeNotification = Notification.Name.lumiConversationsDidChange

    private weak var kernel: LumiKernel?

    /// 项目变更订阅，用于在切换当前项目时把空对话迁移到新项目。
    private var projectChangeCancellable: AnyCancellable?
    /// 上一次观察到的当前项目路径，用于在 `objectWillChange` 触发后判断是否真正发生切换。
    private var previousProjectPath: String?

    public var dataDirectory: URL {
        ConversationManagerRuntimeBridge.shared.dataDirectory ?? ConversationStore.defaultDatabaseRootURL
    }

    // MARK: - Initialization

    public init(kernel: LumiKernel) {
        self.kernel = kernel
        if Self.verbose {
            Self.logger.info("\(Self.t)ConversationManager initialized")
        }
        observeProjectChanges()
    }

    // MARK: - Store Access

    private var store: ConversationStore? {
        ConversationManagerRuntimeBridge.shared.store
    }

    // MARK: - Load

    /// Load a bounded recent cache from store (called during boot).
    public func loadConversations() {
        isLoadingConversations = true
        guard let store else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)Store not available, using empty list")
            }
            conversations = []
            isLoadingConversations = false
            return
        }

        // Synchronous load on MainActor - the store.fetchConversations is async but we await it
        Task { @MainActor in
            let persistedSelectedID = self.loadPersistedSelectedConversationID()
            var loaded = await store.fetchConversationPage(limit: Self.initialPageSize)

            if let persistedSelectedID,
               !loaded.contains(where: { $0.id == persistedSelectedID }),
               let selected = await store.fetchConversation(id: persistedSelectedID),
               selected.parentConversationID == nil {
                loaded.append(selected)
            }

            await MainActor.run {
                self.conversations = loaded
                if self.selectedConversationID == nil {
                    self.selectedConversationID = persistedSelectedID
                }

                // Restore selected conversation if it still exists
                if let selectedID = self.selectedConversationID,
                   !loaded.contains(where: { $0.id == selectedID }) {
                    self.selectedConversationID = loaded.first?.id
                }
                // 初始化全局详细程度为当前选中对话的详细程度
                self.globalVerbosity = self.verbosity(for: self.selectedConversationID)
                self.updateCurrentTitle()
                self.persistSelectedConversationID()
                self.isLoadingConversations = false
                self.notifyConversationsChanged()
                self.notifySelectedConversationChanged()


                if Self.verbose {
                    Self.logger.info("\(Self.t)Loaded \(loaded.count) conversations")
                }
            }
        }
    }

    /// Load a bounded conversation page for settings/history UIs.
    public func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date?,
        beforeID: UUID?
    ) async -> [LumiConversationSummary] {
        await fetchConversationPage(
            limit: limit,
            beforeUpdatedAt: beforeUpdatedAt,
            beforeID: beforeID,
            includingChildConversations: false
        )
    }

    public func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date?,
        beforeID: UUID?,
        includingChildConversations: Bool
    ) async -> [LumiConversationSummary] {
        await store?.fetchConversationPage(
            limit: limit,
            beforeUpdatedAt: beforeUpdatedAt,
            beforeID: beforeID,
            includingChildConversations: includingChildConversations
        ) ?? []
    }

    public func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date?,
        beforeID: UUID?,
        includingChildConversations: Bool,
        projectPath: String
    ) async -> [LumiConversationSummary] {
        await store?.fetchConversationPage(
            limit: limit,
            beforeUpdatedAt: beforeUpdatedAt,
            beforeID: beforeID,
            includingChildConversations: includingChildConversations,
            projectPath: projectPath
        ) ?? []
    }

    public func fetchConversation(id: UUID) async -> LumiConversationSummary? {
        if let cached = conversations.first(where: { $0.id == id }) {
            return cached
        }

        guard let summary = await store?.fetchConversation(id: id) else {
            return nil
        }

        await MainActor.run {
            self.cache(summary)
        }
        return summary
    }

    /// Count conversations without loading their summaries.
    public func conversationCount() async -> Int {
        await store?.conversationCount() ?? 0
    }

    public func conversationCount(projectPath: String?) async -> Int {
        await store?.conversationCount(projectPath: projectPath, includingChildConversations: false) ?? 0
    }

    public func conversationCount(projectPath: String?, includingChildConversations: Bool) async -> Int {
        await store?.conversationCount(
            projectPath: projectPath,
            includingChildConversations: includingChildConversations
        ) ?? 0
    }

    /// Fetch daily conversation counts without loading conversation summaries.
    func fetchDailyCountSeries() async -> ConversationDailyCountSeries {
        await store?.fetchDailyCountSeries() ?? ConversationDailyCountSeries(points: [])
    }

    /// Notify observers that conversations changed
    private func notifyConversationsChanged() {
        kernel?.eventManager.postConversationsDidChange(object: self)
    }

    /// Notify observers that the selected conversation changed.
    ///
    /// 与 `notifyConversationsChanged()`（列表增删/标题）区分：本通知只在
    /// `selectedConversationID` 变化时发，让关心「当前会话」的视图精确订阅。
    private func notifySelectedConversationChanged() {
        kernel?.eventManager.postSelectedConversationDidChange(object: self, conversationID: selectedConversationID)
    }

    // MARK: - ConversationManaging

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
        let effectiveProjectPath = projectPath ?? kernel?.project?.currentProject?.path
        // 如果未指定 providerID，则自动使用当前选中的供应商
        let effectiveProviderID = providerID ?? kernel?.llmProvider?.selectedProviderID
        // 如果未指定 modelName，则自动使用当前选中的模型
        let effectiveModelName = modelName ?? kernel?.llmProvider?.selectedModel
        // 继承全局设置（详细程度、推理强度、语言、自动化程度）
        let effectiveVerbosity = self.globalVerbosity
        let effectiveReasoningEffort = self.reasoningEffort(for: selectedConversationID)
        let effectiveLanguage = self.language(for: selectedConversationID)
        let effectiveAutomationLevel = self.automationLevel(for: selectedConversationID)

        if Self.verbose {
            Self.logger.info("\(Self.t)创建对话：\(normalizedTitle ?? "nil"), 项目：\(effectiveProjectPath ?? "nil"), 供应商：\(effectiveProviderID ?? "nil"), 模型：\(effectiveModelName ?? "nil"), 详细程度：\(effectiveVerbosity.rawValue)")
        }

        let conversation = LumiConversationSummary(
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
                    parentConversationID: parentConversationID
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

    private func cache(_ summary: LumiConversationSummary) {
        guard summary.parentConversationID == nil else { return }
        if let index = conversations.firstIndex(where: { $0.id == summary.id }) {
            conversations[index] = summary
        } else {
            conversations.append(summary)
        }

        guard conversations.count > Self.initialPageSize * 2 else { return }

        let selectedID = selectedConversationID
        let sorted = conversations.sorted { lhs, rhs in
            lhs.lastMessageAt == rhs.lastMessageAt
                ? lhs.createdAt > rhs.createdAt
                : lhs.lastMessageAt > rhs.lastMessageAt
        }
        conversations = Array(sorted.prefix(Self.initialPageSize * 2))

        if let selectedID,
           !conversations.contains(where: { $0.id == selectedID }),
           let selected = sorted.first(where: { $0.id == selectedID }) {
            conversations.append(selected)
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

        conversations.removeAll { $0.id == id }

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
                kernel?.agentTurnManager?.cancelTurn(in: conversationID)
                kernel?.messageManager?.clearMessages(in: conversationID)
                await kernel?.toolManager?.deleteToolCalls(for: conversationID)
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
        kernel?.eventManager.postConversationTitleDidChange(object: self, conversationID: conversationID)

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

    public func mockConversationIDs() -> [UUID] {
        // Return actual conversation IDs for message data association
        conversations.map(\.id)
    }

    // MARK: - Provider/Model Selection

    public func providerID(for conversationID: UUID?) -> String? {
        guard let conversationID else {
            return nil
        }
        return conversations.first { $0.id == conversationID }?.providerID
    }

    public func modelName(for conversationID: UUID?) -> String? {
        guard let conversationID else {
            return nil
        }
        return conversations.first { $0.id == conversationID }?.modelName
    }

    public func selectProvider(id: String, model: String?, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].providerID = id
        conversations[index].modelName = model

        // Persist to database async
        Task {
            await store?.updateConversationProvider(id: conversationID, providerID: id, modelName: model)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)selectProvider: conversation=\(conversationID.uuidString.prefix(8)), provider=\(id), model=\(model ?? "nil")")
        }
    }

    // MARK: - Verbosity

    public func setGlobalVerbosity(_ verbosity: LumiResponseVerbosity) {
        globalVerbosity = verbosity

        if Self.verbose {
            Self.logger.info("\(Self.t)setGlobalVerbosity: verbosity=\(verbosity.rawValue)")
        }
    }

    public func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity {
        guard let conversationID else {
            return .defaultVerbosity
        }
        return conversations.first { $0.id == conversationID }?.verbosity ?? .defaultVerbosity
    }

    public func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].verbosity = verbosity
        // 重新赋值触发 @Published，并广播变更通知，使依赖该会话 verbosity 的视图
        // （消息列表、工具栏等）即时刷新：消息列表会据此重新加载（工具消息的显隐）
        // 并注入新的 verbosity 环境值。
        conversations = conversations
        notifyConversationsChanged()

        Task {
            await store?.updateConversationPreferences(id: conversationID, verbosity: verbosity)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)setVerbosity: conversation=\(conversationID.uuidString.prefix(8)), verbosity=\(verbosity.rawValue)")
        }
    }

    // MARK: - Reasoning Effort

    public func reasoningEffort(for conversationID: UUID?) -> LumiReasoningEffort {
        guard let conversationID else {
            return .defaultEffort
        }
        return conversations.first { $0.id == conversationID }?.reasoningEffort ?? .defaultEffort
    }

    public func setReasoningEffort(_ reasoningEffort: LumiReasoningEffort, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].reasoningEffort = reasoningEffort
        conversations = conversations
        notifyConversationsChanged()

        Task {
            await store?.updateConversationPreferences(id: conversationID, reasoningEffort: reasoningEffort)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)setReasoningEffort: conversation=\(conversationID.uuidString.prefix(8)), effort=\(reasoningEffort.rawValue)")
        }
    }

    public func reasoningEffortOptional(for conversationID: UUID?) -> LumiReasoningEffort? {
        guard let conversationID else {
            return nil
        }
        return conversations.first { $0.id == conversationID }?.reasoningEffort
    }

    public func clearReasoningEffort(for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].reasoningEffort = nil
        conversations = conversations
        notifyConversationsChanged()

        Task {
            await store?.updateConversationPreferences(id: conversationID, setReasoningEffortToNil: true)
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)clearReasoningEffort: conversation=\(conversationID.uuidString.prefix(8))")
        }
    }

    // MARK: - Automation Level

    public func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel {
        guard let conversationID else {
            return .build
        }
        return conversations.first { $0.id == conversationID }?.automationLevel ?? .build
    }

    public func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].automationLevel = automationLevel

        if Self.verbose {
            Self.logger.info("\(Self.t)setAutomationLevel: conversation=\(conversationID.uuidString.prefix(8)), level=\(automationLevel.rawValue)")
        }
    }

    // MARK: - Language

    public func language(for conversationID: UUID?) -> LumiConversationLanguage {
        guard let conversationID else {
            return .chinese
        }
        return conversations.first { $0.id == conversationID }?.language ?? .chinese
    }

    public func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {
        guard let conversationID else {
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            return
        }
        conversations[index].language = language

        if Self.verbose {
            Self.logger.info("\(Self.t)setLanguage: conversation=\(conversationID.uuidString.prefix(8)), language=\(language.rawValue)")
        }
    }

    // MARK: - Project Switch → Migrate Empty Conversations

    /// 订阅内核 `ProjectProviding` 的变更，在当前项目切换时把所有空对话迁移到新项目。
    ///
    /// `objectWillChange` 在 `ProjectService` 的任何 `@Published` 状态（如 `openFileURLs`、
    /// `projects`）变化时都会触发，因此这里通过比较切换前后的 `currentProject.path` 来判断
    /// 是否为真正的「当前项目切换」，避免误迁移。`currentProject.path` 已由
    /// `ProjectService.openProject(at:)` 标准化，与 `createConversation` 写入的路径一致。
    private func observeProjectChanges() {
        guard let project = kernel?.project else { return }
        previousProjectPath = project.currentProject?.path

        projectChangeCancellable = project.objectWillChange
            .map { _ in () }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let newProjectPath = project.currentProject?.path
                guard newProjectPath != self.previousProjectPath else { return }

                // 关闭项目（新路径为 nil）：仅更新缓存，不迁移空对话。
                let oldPath = self.previousProjectPath
                self.previousProjectPath = newProjectPath
                guard let newProjectPath else { return }

                self.reassignEmptyConversations(to: newProjectPath, from: oldPath)
            }
    }

    /// 把所有「没有任何消息」的空对话关联项目更新为 `projectPath`。
    ///
    /// 空判定以「磁盘上是否存在消息」为准：一次批量查询拿到所有有消息的对话 ID，
    /// 取差集得到空对话。整个计算在后台线程执行（SQLite 往返不阻塞 UI），
    /// 仅最后的内存回写与通知回到主线程。
    private func reassignEmptyConversations(to projectPath: String, from oldProjectPath: String?) {
        let messageManager = kernel?.messageManager
        let snapshot = conversations
        let store = store

        Task { [weak self, messageManager, snapshot, store, projectPath, oldProjectPath] in
            let emptyIDs = await Task.detached(priority: .utility) { [messageManager, snapshot] in
                let t0 = ContinuousClock.now
                // 一次批量查询：所有「磁盘上有消息」的对话 ID 集合。
                let havingMessages = messageManager?.conversationIDsHavingMessages() ?? []
                // 空对话 = 快照中不在 havingMessages 里的对话。
                let emptyIDs = snapshot.filter { !havingMessages.contains($0.id) }.map(\.id)

                if Self.verbose {
                    let elapsed = ContinuousClock.now - t0
                    Self.logger.info("\(Self.t)⏱ reassignEmptyConversations 批量查询完成：\(snapshot.count) 个对话，\(emptyIDs.count) 个空，耗时 \(Self.ms(elapsed))ms（后台线程）")
                }

                return emptyIDs
            }.value

            guard !emptyIDs.isEmpty else { return }
            await store?.updateProjectPath(for: emptyIDs, projectPath: projectPath)

            guard let self else { return }
            var updated = false
            let idSet = Set(emptyIDs)
            for index in self.conversations.indices where idSet.contains(self.conversations[index].id) {
                self.conversations[index].projectPath = projectPath
                updated = true
            }
            guard updated else { return }
            self.conversations = self.conversations
            self.notifyConversationsChanged()
            if Self.verbose {
                Self.logger.info("\(Self.t)项目切换 \(oldProjectPath ?? "nil") → \(projectPath)：迁移 \(emptyIDs.count) 个空对话")
            }
        }
    }

    // MARK: - Private

    private func updateCurrentTitle() {
        let newTitle: String
        if let selectedID = selectedConversationID,
           let conversation = conversations.first(where: { $0.id == selectedID }) {
            newTitle = conversation.displayTitle
        } else {
            newTitle = "No conversation"
        }
        // @Published 无条件发布 objectWillChange；值没变时跳过赋值，
        // 避免 selectConversation 触发第二次 kernel 全局广播。
        guard currentTitle != newTitle else { return }
        currentTitle = newTitle
    }

    private func loadPersistedSelectedConversationID() -> UUID? {
        guard let data = try? Data(contentsOf: stateFileURL),
              let state = try? JSONDecoder().decode(ConversationState.self, from: data) else {
            return nil
        }
        return state.selectedConversationID
    }

    private func persistSelectedConversationID() {
        // 主线程零 I/O：编码与原子写盘全部移出点击链路（异步队列）。
        let selectedID = selectedConversationID
        let fileURL = stateFileURL
        let directory = fileURL.deletingLastPathComponent()
        Self.stateWriteQueue.async {
            let state = ConversationState(selectedConversationID: selectedID)
            guard let data = try? JSONEncoder().encode(state) else { return }
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private var stateFileURL: URL {
        dataDirectory
            .appendingPathComponent("state.json", isDirectory: false)
    }
}

// MARK: - Runtime Bridge

private struct ConversationState: Codable {
    let selectedConversationID: UUID?
}

@MainActor
final class ConversationManagerRuntimeBridge: @unchecked Sendable {
    static let shared = ConversationManagerRuntimeBridge()

    var store: ConversationStore?
    var dataDirectory: URL?

    private init() {}
}
