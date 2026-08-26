import Combine
import Foundation
import os
import KitSuperLog

/// `ConversationManaging` 的内存默认实现。
///
/// 复刻自旧版 ConversationManagerPlugin 的 `ConversationManager` 核心逻辑，
/// 去掉内核 / 事件总线 / SQLite 存储依赖，提供最基本的内存对话管理能力：
/// 创建、选择、取消选择、删除、更新标题、标记活跃，以及按对话维度的
/// 详细程度 / 推理强度 / 自动化等级 / 回复语言（全局默认 + 每对话覆盖）。
///
/// 该实现不持久化（骨架阶段）。需要磁盘持久化（SQLite / SwiftData / JSON）
/// 与项目切换迁移等完整能力的宿主应提供自己的实现替换，或子类化扩展。
@MainActor
public final class DefaultConversationManager: ConversationManaging, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.provider-conversation", category: "ProviderConversation")
    nonisolated public static let emoji = "💬"
    nonisolated static let verbose = true

    private static let initialPageSize = 40

    @Published public private(set) var conversations: [ConversationSummary] = []
    @Published public private(set) var selectedConversationID: UUID? {
        didSet {
            guard selectedConversationID != oldValue else { return }
            notifySelectedConversationObservers()
        }
    }
    @Published public private(set) var currentTitle: String = "No conversation"
    @Published public private(set) var isLoadingConversations = false
    @Published public private(set) var globalVerbosity: ResponseVerbosity = .defaultVerbosity
    @Published public private(set) var globalReasoningEffort: ReasoningEffort? = .defaultEffort
    @Published public private(set) var globalAutomationLevel: AutomationLevel = .build
    @Published public private(set) var globalLanguage: ConversationLanguage = .chinese

    /// 按最后消息时间倒序排序
    public var sortedConversations: [ConversationSummary] {
        conversations.sorted { lhs, rhs in
            if lhs.lastMessageAt == rhs.lastMessageAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.lastMessageAt > rhs.lastMessageAt
        }
    }

    /// 数据存储目录；内存实现默认使用 Application Support 下的会话目录，
    /// 供未来持久化 / 选中状态写盘使用。
    public var dataDirectory: URL {
        Self.defaultDataDirectory
    }

    /// 默认数据目录：`~/Library/Application Support/LumiMinimal/Conversations`。
    nonisolated private static let defaultDataDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base
            .appendingPathComponent("LumiMinimal", isDirectory: true)
            .appendingPathComponent("Conversations", isDirectory: true)
    }()

    public init() {
        if Self.verbose {
            Self.logger.info("\(self.t)dataDirectory=\(self.dataDirectory.path, privacy: .public)")
        }
    }

    // MARK: - Load

    /// 加载一批最近对话到内存缓存（骨架阶段直接返回空列表并结束加载态）。
    ///
    /// 有持久化能力的实现应在启动时加载最近一页并恢复选中状态。
    public func loadConversations() {
        isLoadingConversations = false
        if Self.verbose {
            Self.logger.debug("\(self.t)load conversations finished, cached count=\(self.conversations.count)")
        }
    }

    // MARK: - Fetch

    public func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date?,
        beforeID: UUID?
    ) async -> [ConversationSummary] {
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
    ) async -> [ConversationSummary] {
        await fetchConversationPage(
            limit: limit,
            beforeUpdatedAt: beforeUpdatedAt,
            beforeID: beforeID,
            includingChildConversations: includingChildConversations,
            projectPath: ""
        )
    }

    public func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date?,
        beforeID: UUID?,
        includingChildConversations: Bool,
        projectPath: String
    ) async -> [ConversationSummary] {
        let filtered = conversations.filter { summary in
            if !includingChildConversations, summary.parentConversationID != nil { return false }
            if !projectPath.isEmpty, summary.projectPath != projectPath { return false }
            return true
        }
        let sorted = filtered.sorted { lhs, rhs in
            if lhs.lastMessageAt == rhs.lastMessageAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.lastMessageAt > rhs.lastMessageAt
        }
        if let beforeUpdatedAt {
            return Array(sorted.filter { $0.updatedAt < beforeUpdatedAt }.prefix(limit))
        }
        return Array(sorted.prefix(limit))
    }

    public func fetchConversation(id: UUID) async -> ConversationSummary? {
        conversations.first { $0.id == id }
    }

    public func conversationCount(projectPath: String?) async -> Int {
        await conversationCount(projectPath: projectPath, includingChildConversations: false)
    }

    public func conversationCount(projectPath: String?, includingChildConversations: Bool) async -> Int {
        conversations.filter { summary in
            if !includingChildConversations, summary.parentConversationID != nil { return false }
            if let projectPath, summary.projectPath != projectPath { return false }
            return true
        }.count
    }

    public func conversationProjectCount() async -> Int {
        Set(
            conversations
                .filter { $0.parentConversationID == nil }
                .compactMap(\.projectPath)
                .filter { !$0.isEmpty }
        ).count
    }

    // MARK: - Create / Select / Delete

    public func createConversation(
        title: String?,
        projectPath: String?,
        providerID: String?,
        modelName: String?
    ) throws -> UUID {
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

        let conversation = ConversationSummary(
            id: id,
            title: normalizedTitle,
            preview: "",
            createdAt: now,
            updatedAt: now,
            verbosity: globalVerbosity,
            reasoningEffort: globalReasoningEffort,
            language: language(for: selectedConversationID),
            automationLevel: globalAutomationLevel,
            providerID: providerID,
            modelName: modelName,
            projectPath: projectPath,
            parentConversationID: parentConversationID
        )

        // 顶层对话进入缓存并自动选中；子代理对话只返回 id，不进列表。
        if parentConversationID == nil {
            cache(conversation)
            selectedConversationID = id
            updateCurrentTitle()
        }
        if Self.verbose {
            Self.logger.info("\(self.t)created conversation id=\(id.uuidString), title=\(normalizedTitle ?? "nil"), parent=\(parentConversationID?.uuidString ?? "nil"), project=\(projectPath ?? "nil"), provider=\(providerID ?? "nil"), model=\(modelName ?? "nil")")
        }
        return id
    }

    public func selectConversation(id: UUID) {
        selectedConversationID = id
        updateCurrentTitle()
        if Self.verbose {
            Self.logger.debug("\(self.t)selected conversation \(id.uuidString)")
        }
    }

    public func deselectConversation() {
        selectedConversationID = nil
        updateCurrentTitle()
        if Self.verbose {
            Self.logger.debug("\(self.t)deselected conversation")
        }
    }

    public func deleteConversation(id: UUID) {
        conversations.removeAll { $0.id == id }

        if selectedConversationID == id {
            selectedConversationID = conversations.first?.id
            updateCurrentTitle()
        }
        if Self.verbose {
            Self.logger.info("\(self.t)deleted conversation \(id.uuidString), remaining=\(self.conversations.count)")
        }
    }

    // MARK: - Selected Conversation Observation

    @discardableResult
    public func addSelectedConversationObserver(_ callback: @escaping (UUID?) -> Void) -> any SelectedConversationObserverHandle {
        let handle = SelectedConversationObserverHandleImpl(owner: self, callback: callback)
        selectedConversationObservers.append(WeakSelectedConversationObserver(handle))
        return handle
    }

    /// 当前注册的选中对话观察者集合。
    ///
    /// 弱引用持有令牌：外部释放令牌后，其 deinit 即视为自动注销，
    /// 下次广播时清理已失效的弱引用。
    private var selectedConversationObservers: [WeakSelectedConversationObserver] = []

    /// 从集合中移除指定观察者（供令牌的 cancel 调用）。
    fileprivate func removeSelectedConversationObserver(_ handle: SelectedConversationObserverHandle) {
        selectedConversationObservers.removeAll { $0.handle === handle }
    }
    /// 向所有已注册观察者广播最新选中 ID。
    ///
    /// 先清理已释放令牌并复制再遍历，避免回调中注销自身导致数组在遍历期间变化。
    private func notifySelectedConversationObservers() {
        selectedConversationObservers.removeAll { $0.handle == nil }
        let observers = selectedConversationObservers
        let selectedID = selectedConversationID
        for observer in observers {
            observer.handle?.invoke(selectedID)
        }
    }

    public func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else {
            if Self.verbose {
                Self.logger.warning("\(self.t)update title failed: conversation \(conversationID.uuidString) not found")
            }
            return false
        }
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedTitle = normalized.isEmpty ? nil : normalized
        conversations[index].title = storedTitle

        if conversationID == selectedConversationID {
            updateCurrentTitle()
        }
        if Self.verbose {
            Self.logger.debug("\(self.t)updated title for \(conversationID.uuidString): \(storedTitle ?? "nil")")
        }
        return true
    }

    public func markConversationActive(id: UUID, messageDate: Date) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else {
            if Self.verbose {
                Self.logger.warning("\(self.t)mark active skipped: conversation \(id.uuidString) not found")
            }
            return
        }
        conversations[index].lastMessageAt = messageDate
        conversations[index].updatedAt = Date()
        conversations = conversations
        if Self.verbose {
            Self.logger.debug("\(self.t)marked conversation \(id.uuidString) active")
        }
    }

    public func isSending(for conversationID: UUID?) -> Bool {
        // 骨架阶段无发送链路，恒为 false。
        false
    }

    // MARK: - Provider/Model

    public func providerID(for conversationID: UUID?) -> String? {
        guard let conversationID else { return nil }
        return conversations.first { $0.id == conversationID }?.providerID
    }

    public func modelName(for conversationID: UUID?) -> String? {
        guard let conversationID else { return nil }
        return conversations.first { $0.id == conversationID }?.modelName
    }

    public func selectProvider(id: String, model: String?, for conversationID: UUID?) {
        guard let conversationID,
              let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[index].providerID = id
        conversations[index].modelName = model
    }

    // MARK: - Verbosity

    public func setGlobalVerbosity(_ verbosity: ResponseVerbosity) {
        globalVerbosity = verbosity
    }

    public func verbosity(for conversationID: UUID?) -> ResponseVerbosity {
        guard let conversationID else { return globalVerbosity }
        return conversations.first { $0.id == conversationID }?.verbosity ?? globalVerbosity
    }

    public func setVerbosity(_ verbosity: ResponseVerbosity, for conversationID: UUID?) {
        guard let conversationID else {
            setGlobalVerbosity(verbosity)
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[index].verbosity = verbosity
        conversations = conversations
    }

    // MARK: - Reasoning Effort

    public func setGlobalReasoningEffort(_ reasoningEffort: ReasoningEffort?) {
        globalReasoningEffort = reasoningEffort
    }

    public func reasoningEffort(for conversationID: UUID?) -> ReasoningEffort {
        guard let conversationID else { return globalReasoningEffort ?? .defaultEffort }
        return conversations.first { $0.id == conversationID }?.reasoningEffort ?? globalReasoningEffort ?? .defaultEffort
    }

    public func reasoningEffortOptional(for conversationID: UUID?) -> ReasoningEffort? {
        guard let conversationID else { return globalReasoningEffort }
        return conversations.first { $0.id == conversationID }?.reasoningEffort ?? globalReasoningEffort
    }

    public func setReasoningEffort(_ reasoningEffort: ReasoningEffort, for conversationID: UUID?) {
        guard let conversationID else {
            setGlobalReasoningEffort(reasoningEffort)
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[index].reasoningEffort = reasoningEffort
        conversations = conversations
    }

    public func clearReasoningEffort(for conversationID: UUID?) {
        guard let conversationID else {
            setGlobalReasoningEffort(nil)
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[index].reasoningEffort = nil
        conversations = conversations
    }

    // MARK: - Automation Level

    public func setGlobalAutomationLevel(_ automationLevel: AutomationLevel) {
        globalAutomationLevel = automationLevel
    }

    public func automationLevel(for conversationID: UUID?) -> AutomationLevel {
        guard let conversationID else { return globalAutomationLevel }
        return conversations.first { $0.id == conversationID }?.automationLevel ?? globalAutomationLevel
    }

    public func setAutomationLevel(_ automationLevel: AutomationLevel, for conversationID: UUID?) {
        guard let conversationID else {
            setGlobalAutomationLevel(automationLevel)
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[index].automationLevel = automationLevel
        conversations = conversations
    }

    // MARK: - Language

    public func language(for conversationID: UUID?) -> ConversationLanguage {
        guard let conversationID else { return globalLanguage }
        return conversations.first { $0.id == conversationID }?.language ?? globalLanguage
    }

    public func setGlobalLanguage(_ language: ConversationLanguage) {
        globalLanguage = language
    }

    public func setLanguage(_ language: ConversationLanguage, for conversationID: UUID?) {
        guard let conversationID else {
            setGlobalLanguage(language)
            return
        }
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        conversations[index].language = language
    }

    // MARK: - Private

    /// 把顶层对话写入有界内存缓存：存在则更新，否则追加；超过上限时截断到
    /// `initialPageSize * 2`，并保证选中对话不被淘汰。
    private func cache(_ summary: ConversationSummary) {
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

    private func updateCurrentTitle() {
        let newTitle: String
        if let selectedID = selectedConversationID,
           let conversation = conversations.first(where: { $0.id == selectedID }) {
            newTitle = conversation.displayTitle
        } else {
            newTitle = "No conversation"
        }
        // @Published 无条件发布 objectWillChange；值没变时跳过赋值，
        // 避免 selectConversation 触发第二次容器级广播。
        guard currentTitle != newTitle else { return }
        currentTitle = newTitle
    }
}

/// `DefaultConversationManager` 的选中观察者令牌实现。
///
/// 弱引用 owner，避免与管理器形成引用环；令牌被外部释放后，管理器侧
/// 持有的弱引用自动失效，并在下次广播时清理，因此调用方无需手动反注册。
@MainActor
private final class SelectedConversationObserverHandleImpl: SelectedConversationObserverHandle {
    private weak var owner: DefaultConversationManager?
    private let callback: (UUID?) -> Void
    private var isCancelled = false

    init(owner: DefaultConversationManager, callback: @escaping (UUID?) -> Void) {
        self.owner = owner
        self.callback = callback
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        owner?.removeSelectedConversationObserver(self)
    }

    /// 通知回调（已注销的令牌不再触发）。
    fileprivate func invoke(_ selectedID: UUID?) {
        guard !isCancelled else { return }
        callback(selectedID)
    }
}

/// 观察者集合的元素：弱引用持有令牌，令牌被外部释放后自动失效。
@MainActor
private final class WeakSelectedConversationObserver {
    fileprivate weak var handle: SelectedConversationObserverHandleImpl?

    init(_ handle: SelectedConversationObserverHandleImpl) {
        self.handle = handle
    }
}
