import Foundation
import KernelCore
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderLLMManager
import ProviderMessage
import ProviderProject
import ProviderToolManager
import KitSuperLog

/// Conversation Manager - real implementation using SwiftData persistence
@MainActor
public final class ConversationManager: ObservableObject, ConversationManaging, SuperLog {
    private static let initialPageSize = 40
    /// 选中状态写盘队列：串行执行，保证连续切换会话时最后一次写入生效。
    private nonisolated static let stateWriteQueue = DispatchQueue(
        label: "com.coffic.lumi.conversation-manager.state-write",
        qos: .utility
    )
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-manager")
    public nonisolated static let emoji = "💬"
    public nonisolated static let verbose = false

    @Published public internal(set) var conversations: [ConversationSummary] = []
    @Published public internal(set) var selectedConversationID: UUID? {
        didSet {
            guard selectedConversationID != oldValue else { return }
            notifySelectedConversationObservers()
            notifyConversationObservers(.selected(selectedConversationID))
        }
    }

    @Published public internal(set) var currentTitle: String = "No conversation"
    @Published public internal(set) var isLoadingConversations = true
    @Published public internal(set) var globalVerbosity: ResponseVerbosity = .defaultVerbosity
    @Published public internal(set) var globalReasoningEffort: ReasoningEffort? = .defaultEffort
    @Published public internal(set) var globalAutomationLevel: AutomationLevel = .build
    @Published public internal(set) var globalLanguage: ConversationLanguage = .chinese

    /// 会话列表刷新去抖任务。消息写入会高频更新 lastMessageAt，侧栏排序不需要同步跟随每一次变化。
    private var conversationsChangeTask: Task<Void, Never>?

    /// 按最后消息时间倒序排序
    public var sortedConversations: [ConversationSummary] {
        conversations.sorted { lhs, rhs in
            if lhs.lastMessageAt == rhs.lastMessageAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.lastMessageAt > rhs.lastMessageAt
        }
    }

    // MARK: - Injected Dependencies (v2: resolved from KernelCore)

    let store: ConversationStore?
    public let dataDirectory: URL
    let project: (any ProjectProviding)?
    let llmProviderManager: (any LLMManaging)?
    let messageManager: (any MessageManaging)?
    let toolManager: (any ToolManagerProviding)?
    let agentTurn: (any AgentLoopProviding)?
    let eventBus: KernelCoreEventBus?

    // MARK: - Initialization

    public init(
        store: ConversationStore?,
        dataDirectory: URL,
        project: (any ProjectProviding)? = nil,
        llmProviderManager: (any LLMManaging)? = nil,
        messageManager: (any MessageManaging)? = nil,
        toolManager: (any ToolManagerProviding)? = nil,
        agentTurn: (any AgentLoopProviding)? = nil,
        eventBus: KernelCoreEventBus? = nil
    ) {
        self.store = store
        self.dataDirectory = dataDirectory
        self.project = project
        self.llmProviderManager = llmProviderManager
        self.messageManager = messageManager
        self.toolManager = toolManager
        self.agentTurn = agentTurn
        self.eventBus = eventBus
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
                if self.selectedConversationID != nil {
                    self.globalReasoningEffort = self.reasoningEffortOptional(for: self.selectedConversationID)
                    self.globalAutomationLevel = self.automationLevel(for: self.selectedConversationID)
                    self.globalLanguage = self.language(for: self.selectedConversationID)
                }
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

    /// Notify observers that conversations changed.
    ///
    /// v2 无事件管理器：@Published 已驱动 `registerProvider` 的 objectWillChange 转发；
    /// 这里额外以类型化事件发布 + 旧 Notification 桥接，兼容尚未迁移的消费者。
    func notifyConversationsChanged() {
        // 创建、删除、标题更新等明确的结构变化需要立即通知；同时取消尚未发出的活跃会话去抖通知，
        // 避免一次变更产生重复的侧栏刷新。
        conversationsChangeTask?.cancel()
        conversationsChangeTask = nil
        notifyConversationObservers(.listChanged)
        eventBus?.publishAsLegacy(
            ConversationsDidChangeEvent(),
            notificationName: .lumiConversationsDidChange
        )
    }

    /// 延迟并合并消息带来的侧栏刷新。内存中的会话摘要已经在调用方立即更新，
    /// 这里只控制列表消费者何时重新加载和排序。
    func scheduleConversationsChangedNotification() {
        conversationsChangeTask?.cancel()
        conversationsChangeTask = Task(priority: .utility) { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, let self else { return }
            self.conversationsChangeTask = nil
            self.notifyConversationsChanged()
        }
    }

    /// Notify observers that the selected conversation changed.
    func notifySelectedConversationChanged() {
        eventBus?.publishAsLegacy(
            SelectedConversationDidChangeEvent(conversationID: selectedConversationID),
            notificationName: .lumiSelectedConversationDidChange,
            userInfo: selectedConversationID.map { ["conversationID": $0] }
        )
    }

    /// 当前注册的选中对话观察者集合（弱引用持有令牌：外部释放令牌后自动失效）。
    var selectedConversationObservers: [WeakSelectedConversationObserver] = []
    var conversationObservers: [WeakConversationObserver] = []

    @discardableResult
    public func addConversationObserver(_ callback: @escaping (ConversationEvent) -> Void) -> any ConversationObserverHandle {
        let handle = ConversationObserverHandleImpl(owner: self, callback: callback)
        conversationObservers.append(WeakConversationObserver(handle))
        return handle
    }

    /// 从集合中移除指定观察者（供令牌 cancel 调用）。
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

    func removeConversationObserver(_ handle: ConversationObserverHandleImpl) {
        conversationObservers.removeAll { $0.handle === handle }
    }

    func notifyConversationObservers(_ event: ConversationEvent) {
        conversationObservers.removeAll { $0.handle == nil }
        let observers = conversationObservers
        for observer in observers {
            observer.handle?.invoke(event)
        }
    }

    func cache(_ summary: ConversationSummary) {
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

    func updateCurrentTitle() {
        let newTitle: String
        if let selectedID = selectedConversationID,
           let conversation = conversations.first(where: { $0.id == selectedID }) {
            newTitle = conversation.displayTitle
        } else {
            newTitle = "No conversation"
        }
        // @Published 无条件发布 objectWillChange；值没变时跳过赋值，
        // 避免 selectConversation 触发第二次全局广播。
        guard currentTitle != newTitle else { return }
        currentTitle = newTitle
    }

    func loadPersistedSelectedConversationID() -> UUID? {
        guard let data = try? Data(contentsOf: stateFileURL),
              let state = try? JSONDecoder().decode(ConversationState.self, from: data) else {
            return nil
        }
        return state.selectedConversationID
    }

    func persistSelectedConversationID() {
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

    var stateFileURL: URL {
        dataDirectory
            .appendingPathComponent("state.json", isDirectory: false)
    }
}

// MARK: - State

private struct ConversationState: Codable {
    let selectedConversationID: UUID?
}

// MARK: - Selected Conversation Observer

/// `ConversationManager` 的选中对话观察者令牌实现。
///
/// 弱引用 owner，避免与管理器形成引用环；令牌被外部释放后，管理器侧
/// 持有的弱引用自动失效，并在下次广播时清理，因此调用方无需手动反注册。
@MainActor
final class ConversationSelectedConversationObserverHandle: SelectedConversationObserverHandle {
    private weak var owner: ConversationManager?
    let callback: (UUID?) -> Void
    private var isCancelled = false

    init(owner: ConversationManager, callback: @escaping (UUID?) -> Void) {
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
final class WeakSelectedConversationObserver {
    weak var handle: ConversationSelectedConversationObserverHandle?

    init(_ handle: ConversationSelectedConversationObserverHandle) {
        self.handle = handle
    }
}
