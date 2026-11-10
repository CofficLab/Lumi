import Foundation
import KernelCore
import os
import ProviderAgentLoop
import ProviderConversation
import ProviderLLMManager
import ProviderMessage
import ProviderProject
import ProviderToolManager
import LumiLoggingKit
/// Conversation Manager - real implementation using SwiftData persistence
@MainActor
public final class ConversationManager: ConversationManaging, SuperLog {
    private static let initialPageSize = 40
    /// 选中状态写盘队列：串行执行，保证连续切换会话时最后一次写入生效。
    private nonisolated static let stateWriteQueue = DispatchQueue(
        label: "com.coffic.lumi.conversation-manager.state-write",
        qos: .utility
    )
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-manager")
    public nonisolated static let emoji = "💬"
    public nonisolated static let verbose = false

    public internal(set) var conversations: [ConversationSummary] = []
    /// 缓存数组之外的会话模型选择；列表整表重载或旧会话不在窗口内时仍然生效。
    var modelIDOverrides: [UUID: String] = [:]
    /// 缓存数组之外的会话语言；后台会话被挤出有界缓存后，下一次请求仍须用它自己的
    /// 语言而不是 New Chat 的全局默认值（issue #984）。
    var languageOverrides: [UUID: ConversationLanguage] = [:]
    /// 缓存数组之外的会话自动化级别；后台会话被挤出有界缓存后，工具可用性与
    /// 授权策略仍须按用户为该会话选择的值执行（issue #1008）。
    var automationLevelOverrides: [UUID: AutomationLevel] = [:]
    /// 缓存数组之外的会话推理强度；后台回合被挤出有界缓存后，下一次 LLM 请求
    /// 仍须携带用户为它保存的档位，而不是把「未加载」当成「未设置」（issue #892）。
    var reasoningEffortOverrides: [UUID: ReasoningEffort] = [:]
    public internal(set) var selectedConversationID: UUID? {
        didSet {
            guard selectedConversationID != oldValue else { return }
            // Publish selection only after the cached title reflects the new
            // conversation. Observers commonly read `currentTitle` from the
            // `.selected` callback to refresh their UI.
            updateCurrentTitle()
            notifySelectedConversationObservers()
            notifyConversationObservers(.selected(selectedConversationID))
        }
    }

    public internal(set) var currentTitle: String = "No conversation"
    public internal(set) var isLoadingConversations = true
    public internal(set) var globalVerbosity: ResponseVerbosity = .defaultVerbosity
    public internal(set) var globalReasoningEffort: ReasoningEffort? = .defaultEffort
    public internal(set) var globalAutomationLevel: AutomationLevel = .build
    public internal(set) var globalLanguage: ConversationLanguage = .chinese

    /// 会话列表刷新去抖任务。消息写入会高频更新 lastMessageAt，侧栏排序不需要同步跟随每一次变化。
    private var conversationsChangeTask: Task<Void, Never>?

    /// 按最后消息时间倒序排序
    public var sortedConversations: [ConversationSummary] {
        conversations.sorted { lhs, rhs in
            if lhs.lastMessageAt == rhs.lastMessageAt {
                // 与数据库 keyset 的 `sortKey` 一样需要稳定 tie-break。哈希细节留在 Store，
                // 内存列表只需保证同一时间戳下顺序确定。
                return lhs.id.uuidString > rhs.id.uuidString
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

    /// 项目切换观察者：监听当前项目变化，清空对话选择。
    private var projectObserver: (any ProjectProvidingObserverHandle)?

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

        // 监听项目切换，仅在用户主动切换时清空对话选择
        projectObserver = project?.addObserver { [weak self] event in
            guard case .currentProjectChanged(_, reason: .userSelected) = event else { return }
            self?.deselectConversation()
        }
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
            _ = await store.migrateLegacyModelSelections()
            let persistedState = self.loadPersistedState()
            let persistedSelectedID = persistedState?.selectedConversationID
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
                // New Chat 的默认语言独立于选中会话，必须跨重启保留；
                // 选中会话存在时，下面的会话级恢复仍会覆盖它。
                if let persistedLanguage = persistedState?.globalLanguage {
                    self.globalLanguage = persistedLanguage
                }
                // New Chat 的默认详细度同样独立于选中会话，必须先恢复；有选中会话时
                // 下面的会话级复制仍会覆盖它。
                if let persistedVerbosity = persistedState?.globalVerbosity {
                    self.globalVerbosity = persistedVerbosity
                }
                if self.selectedConversationID != nil {
                    // 初始化全局详细程度为当前选中对话的详细程度
                    self.globalVerbosity = self.verbosity(for: self.selectedConversationID)
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
    /// 以类型化事件发布，并保留旧 Notification 桥接，兼容尚未迁移的消费者。
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
        // 摘要一旦进入过缓存，就记住它的显式语言；后续被裁剪出窗口时，
        // `language(for:)` 仍能读到会话自己的设置（issue #984）。
        if let language = summary.language {
            languageOverrides[summary.id] = language
        }
        // 显式模型绑定同样要跨缓存淘汰保留：后台会话的排队回合会在新回合开始时
        // 按 ID 查询模型，丢失后会静默改用全局模型（issue #987）。
        if let modelID = summary.modelID {
            modelIDOverrides[summary.id] = modelID
        }
        // 自动化级别同样要跨缓存淘汰保留：后台回合在淘汰后仍会按会话 ID
        // 查询该值，丢失后会回退 Build，改变工具授权策略（issue #1008）。
        if let automationLevel = summary.automationLevel {
            automationLevelOverrides[summary.id] = automationLevel
        }
        // 推理强度同理：后台会话的下一请求直接读取该值，丢失后会把
        // 「摘要不在缓存」当成「用户未设置」，静默丢掉已保存的档位（issue #892）。
        if let reasoningEffort = summary.reasoningEffort {
            reasoningEffortOverrides[summary.id] = reasoningEffort
        }
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

    /// 把从存储补载的摘要写入缓存。
    ///
    /// 选中会话不在缓存时，UI 已按 `.defaultVerbosity` 渲染；水合后再读缓存
    /// 虽然能拿到真实值，但工具栏与消息列表只监听 `.verbosityChanged`，
    /// 不发事件就会一直停在缺省值（issue #1069）。只在选中会话的有效详细度
    /// 真正变化时补发，避免无关的缓存写入触发 UI 刷新。
    func cacheHydratedSummary(_ summary: ConversationSummary) {
        let previousVerbosity = verbosity(for: summary.id)
        cache(summary)
        guard summary.id == selectedConversationID,
              verbosity(for: summary.id) != previousVerbosity else {
            return
        }
        notifyConversationObservers(.verbosityChanged(summary.id))
    }

    func updateCurrentTitle() {
        let newTitle: String
        if let selectedID = selectedConversationID,
           let conversation = conversations.first(where: { $0.id == selectedID }) {
            newTitle = conversation.displayTitle
        } else {
            newTitle = "No conversation"
        }
        // 值没变时跳过赋值，避免 selectConversation 触发重复状态更新。
        guard currentTitle != newTitle else { return }
        currentTitle = newTitle
    }

    private func loadPersistedState() -> ConversationState? {
        guard let data = try? Data(contentsOf: stateFileURL),
              let state = try? JSONDecoder().decode(ConversationState.self, from: data) else {
            return nil
        }
        return state
    }

    func persistSelectedConversationID() {
        // 主线程零 I/O：编码与原子写盘全部移出点击链路（异步队列）。
        let selectedID = selectedConversationID
        let verbosity = globalVerbosity
        let language = globalLanguage
        let fileURL = stateFileURL
        let directory = fileURL.deletingLastPathComponent()
        Self.stateWriteQueue.async {
            let state = ConversationState(
                selectedConversationID: selectedID,
                globalVerbosity: verbosity,
                globalLanguage: language
            )
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
    /// 旧版本 `state.json` 不含这些全局字段，用可选值兼容解码。
    let globalVerbosity: ResponseVerbosity?
    let globalLanguage: ConversationLanguage?
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
    private var forwardedHandle: (any SelectedConversationObserverHandle)?

    init(owner: ConversationManager, callback: @escaping (UUID?) -> Void) {
        self.owner = owner
        self.callback = callback
    }

    func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        owner?.removeSelectedConversationObserver(self)
        forwardedHandle?.cancel()
        forwardedHandle = nil
    }

    func transfer(to replacement: any ConversationManaging) {
        forwardedHandle?.cancel()
        forwardedHandle = replacement.addSelectedConversationObserver(callback)
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
