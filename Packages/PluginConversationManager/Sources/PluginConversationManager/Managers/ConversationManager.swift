import Combine
import Foundation
import KernelCore
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderLLMManager
import ProviderMessage
import ProviderProject
import ProviderToolManager
import SuperLogKit

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

    @Published public internal(set) var conversations: [LumiConversationSummary] = []
    @Published public internal(set) var selectedConversationID: UUID? {
        didSet {
            guard selectedConversationID != oldValue else { return }
            notifySelectedConversationObservers()
        }
    }

    @Published public internal(set) var currentTitle: String = "No conversation"
    @Published public internal(set) var isLoadingConversations = true
    @Published public internal(set) var globalVerbosity: LumiResponseVerbosity = .defaultVerbosity
    @Published public internal(set) var globalReasoningEffort: LumiReasoningEffort? = .defaultEffort
    @Published public internal(set) var globalAutomationLevel: LumiAutomationLevel = .build
    @Published public internal(set) var globalLanguage: LumiConversationLanguage = .chinese

    /// 按最后消息时间倒序排序
    public var sortedConversations: [LumiConversationSummary] {
        conversations.sorted { lhs, rhs in
            if lhs.lastMessageAt == rhs.lastMessageAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.lastMessageAt > rhs.lastMessageAt
        }
    }

    /// 项目变更订阅，用于在切换当前项目时把空对话迁移到新项目。
    var projectChangeCancellable: AnyCancellable?
    /// 上一次观察到的当前项目路径，用于在 `objectWillChange` 触发后判断是否真正发生切换。
    var previousProjectPath: String?

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
        observeProjectChanges()
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
        eventBus?.publishAsLegacy(
            ConversationsDidChangeEvent(),
            notificationName: .lumiConversationsDidChange
        )
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

    func cache(_ summary: LumiConversationSummary) {
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
    private let callback: (UUID?) -> Void
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
    fileprivate weak var handle: ConversationSelectedConversationObserverHandle?

    init(_ handle: ConversationSelectedConversationObserverHandle) {
        self.handle = handle
    }
}
