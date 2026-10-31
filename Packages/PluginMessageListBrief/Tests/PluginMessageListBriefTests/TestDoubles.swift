import Foundation
import ProviderLifecycleHooks
import ProviderAgentLoop
import ProviderChatSection
import ProviderConversation
import ProviderConversationState
import ProviderDeveloperMode
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageStreaming
import SwiftUI
@testable import PluginMessageListBrief

/// Observer / Capability Adapter / 插件装配测试共用的 in-memory Provider 替身。
///
/// 这些测试针对的是「事件 → VM 状态」的转发链路，与真实持久化实现无关。
/// 所有 Provider 协议都提供了默认实现，因此 stub 只需覆盖被观测的少量成员，
/// 其余一律走协议默认行为。
enum ProviderTestDoubles {

    // MARK: - Handles

    /// 可计数的注销令牌，用于验证 Observer 确实释放了订阅。
    ///
    /// `onCancel` 让持有 handle 的 stub 在 `cancel()` 时清理自身订阅回调，
    /// 否则 Provider 侧仍会向已注销的闭包派发事件。
    @MainActor
    final class CountingHandle: ConversationObserverHandle {
        private(set) var cancelCount = 0
        var onCancel: (() -> Void)?
        func cancel() {
            cancelCount += 1
            onCancel?()
        }
    }

    @MainActor
    final class CountingSelectedHandle: SelectedConversationObserverHandle {
        private(set) var cancelCount = 0
        var onCancel: (() -> Void)?
        func cancel() {
            cancelCount += 1
            onCancel?()
        }
    }

    @MainActor
    final class CountingMessageHandle: MessageChangeObserverHandle {
        private(set) var cancelCount = 0
        var onCancel: (() -> Void)?
        func cancel() {
            cancelCount += 1
            onCancel?()
        }
    }

    @MainActor
    final class CountingDeveloperModeHandle: DeveloperModeProvidingObserverHandle {
        private(set) var cancelCount = 0
        var onCancel: (() -> Void)?
        func cancel() {
            cancelCount += 1
            onCancel?()
        }
    }

    @MainActor
    final class CountingChatSectionHandle: ChatSectionProvidingObserverHandle {
        private(set) var cancelCount = 0
        func cancel() { cancelCount += 1 }
    }

    // MARK: - MessageManaging

    /// 支持手动 emit `MessageChange` 的消息管理器。
    ///
    /// 除观测接口外，只实现 Observer 测试需要读写的最小消息存储；
    /// 分页查询走协议默认实现（由 `messages(for:)` 派生）。
    @MainActor
    final class StubMessageManager: MessageManaging {
        private(set) var stored: [Message] = []
        var handle = CountingMessageHandle()
        private var observer: ((MessageChange) -> Void)?

        init(messages: [Message] = []) { stored = messages }

        func messages(for conversationID: UUID) -> [Message] {
            stored.filter { $0.conversationID == conversationID }
        }

        func messagesSnapshot(in conversationID: UUID) async -> [Message] {
            messages(for: conversationID)
        }

        func firstUserMessage(in conversationID: UUID) async -> Message? {
            messages(for: conversationID).first { $0.role == .user && !$0.content.isEmpty }
        }

        func messagesForLLM(in conversationID: UUID) async -> [Message] {
            messages(for: conversationID)
        }

        func messagePage(
            for conversationID: UUID,
            limit: Int,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) -> [Message] {
            let all = messages(for: conversationID).sorted { $0.createdAt < $1.createdAt }
            guard let beforeMessageID else { return Array(all.suffix(limit)) }
            guard let index = all.firstIndex(where: { $0.id == beforeMessageID }) else { return [] }
            return Array(all[max(0, index - limit)..<index])
        }

        func messagePageAsync(
            for conversationID: UUID,
            limit: Int,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) -> [Message] {
            messagePage(
                for: conversationID,
                limit: limit,
                beforeMessageID: beforeMessageID,
                includesToolMessages: includesToolMessages
            )
        }

        func hasEarlierMessages(
            for conversationID: UUID,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) -> Bool {
            let all = messages(for: conversationID)
            guard let beforeMessageID else { return all.count > 1 }
            guard let index = all.firstIndex(where: { $0.id == beforeMessageID }) else { return false }
            return index > 0
        }

        func hasEarlierMessagesAsync(
            for conversationID: UUID,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) -> Bool {
            hasEarlierMessages(
                for: conversationID,
                beforeMessageID: beforeMessageID,
                includesToolMessages: includesToolMessages
            )
        }

        func message(id: UUID, in conversationID: UUID) -> Message? {
            stored.first { $0.id == id && $0.conversationID == conversationID }
        }

        func lastMessage(in conversationID: UUID) -> Message? {
            messages(for: conversationID).sorted { $0.createdAt < $1.createdAt }.last
        }

        func messageCount(for conversationID: UUID) -> Int {
            messages(for: conversationID).count
        }

        func insertMessage(_ message: Message, to conversationID: UUID) {
            stored.removeAll { $0.id == message.id }
            stored.append(message)
        }

        func updateMessage(id: UUID, in conversationID: UUID, content: String) {
            guard let index = stored.firstIndex(where: { $0.id == id }) else { return }
            stored[index].content = content
        }

        func deleteMessage(id: UUID, in conversationID: UUID) {
            stored.removeAll { $0.id == id }
        }

        func clearMessages(in conversationID: UUID) {
            stored.removeAll { $0.conversationID == conversationID }
        }

        func updateToolCallResult(
            _ result: MessageToolResult,
            toolCallID: String,
            assistantMessageID: UUID,
            in conversationID: UUID,
            authorizationState: String?
        ) {}

        func emit(_ change: MessageChange) { observer?(change) }

        func addMessageChangeObserver(
            _ callback: @escaping (MessageChange) -> Void
        ) -> any MessageChangeObserverHandle {
            observer = callback
            handle.onCancel = { [weak self] in self?.observer = nil }
            return handle
        }
    }

    // MARK: - ConversationManaging

    /// 支持手动 emit `ConversationEvent` 与切换选中态的会话管理器。
    ///
    /// 协议面很大，未覆盖的成员一律走 `ConversationManaging` 的默认扩展
    /// （`fetchConversationPage` / `count` / `sortedConversations` 等）。
    @MainActor
    final class StubConversationManager: ConversationManaging {
        private(set) var summaries: [ConversationSummary]
        var selected: UUID?
        var verbosityValue: ResponseVerbosity
        var loadingConversations = false
        var selectedHandle = CountingSelectedHandle()
        var conversationHandle = CountingHandle()
        private var selectedObserver: ((UUID?) -> Void)?
        private var conversationObserver: ((ConversationEvent) -> Void)?

        init(
            selected: UUID? = nil,
            verbosity: ResponseVerbosity = .brief,
            summaries: [ConversationSummary] = []
        ) {
            self.selected = selected
            self.verbosityValue = verbosity
            self.summaries = summaries
        }

        var conversations: [ConversationSummary] { summaries }
        var selectedConversationID: UUID? { selected }
        var currentTitle: String { summaries.first(where: { $0.id == selected })?.title ?? "" }
        var isLoadingConversations: Bool { loadingConversations }
        var dataDirectory: URL { URL(fileURLWithPath: "/tmp/PluginMessageListBriefTests") }

        var globalVerbosity: ResponseVerbosity { verbosityValue }

        func setGlobalVerbosity(_ verbosity: ResponseVerbosity) { verbosityValue = verbosity }

        func verbosity(for conversationID: UUID?) -> ResponseVerbosity { verbosityValue }
        func setVerbosity(_ verbosity: ResponseVerbosity, for conversationID: UUID?) {
            verbosityValue = verbosity
        }

        func createConversation(
            title: String?,
            projectPath: String?,
            providerID: String?,
            modelName: String?
        ) throws -> UUID {
            let id = UUID()
            summaries.append(ConversationSummary(
                id: id,
                title: title ?? "",
                createdAt: Date(),
                updatedAt: Date(),
                projectPath: projectPath
            ))
            return id
        }

        func createConversation(
            title: String?,
            projectPath: String?,
            providerID: String?,
            modelName: String?,
            parentConversationID: UUID?
        ) throws -> UUID {
            try createConversation(
                title: title,
                projectPath: projectPath,
                providerID: providerID,
                modelName: modelName
            )
        }

        func selectConversation(id: UUID) {
            guard selected != id else { return }
            selected = id
            selectedObserver?(id)
        }

        func deselectConversation() {
            guard selected != nil else { return }
            selected = nil
            selectedObserver?(nil)
        }

        func deleteConversation(id: UUID) {
            summaries.removeAll { $0.id == id }
        }

        func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool {
            guard let index = summaries.firstIndex(where: { $0.id == conversationID }) else { return false }
            summaries[index].title = title
            return true
        }

        func markConversationActive(id: UUID, messageDate: Date) {}
        func isSending(for conversationID: UUID?) -> Bool { false }

        func addSelectedConversationObserver(
            _ callback: @escaping (UUID?) -> Void
        ) -> any SelectedConversationObserverHandle {
            selectedObserver = callback
            selectedHandle.onCancel = { [weak self] in self?.selectedObserver = nil }
            return selectedHandle
        }

        func addConversationObserver(
            _ callback: @escaping (ConversationEvent) -> Void
        ) -> any ConversationObserverHandle {
            conversationObserver = callback
            conversationHandle.onCancel = { [weak self] in self?.conversationObserver = nil }
            return conversationHandle
        }

        // MARK: Test driving

        func emit(_ event: ConversationEvent) { conversationObserver?(event) }
        func emitSelection(_ id: UUID?) { selected = id; selectedObserver?(id) }

        // MARK: Unused protocol members

        func modelID(for conversationID: UUID?) -> String? { nil }
        func selectModel(id: String, for conversationID: UUID?) {}
        func providerID(for conversationID: UUID?) -> String? { nil }
        func modelName(for conversationID: UUID?) -> String? { nil }
        func selectProvider(id: String, model: String?, for conversationID: UUID?) {}
        var globalReasoningEffort: ReasoningEffort? { .high }
        func setGlobalReasoningEffort(_ reasoningEffort: ReasoningEffort?) {}
        func reasoningEffort(for conversationID: UUID?) -> ReasoningEffort { .high }
        func reasoningEffortOptional(for conversationID: UUID?) -> ReasoningEffort? { .high }
        func setReasoningEffort(_ reasoningEffort: ReasoningEffort, for conversationID: UUID?) {}
        func clearReasoningEffort(for conversationID: UUID?) {}
        var globalAutomationLevel: AutomationLevel { .chat }
        func setGlobalAutomationLevel(_ automationLevel: AutomationLevel) {}
        func automationLevel(for conversationID: UUID?) -> AutomationLevel { .chat }
        func setAutomationLevel(_ automationLevel: AutomationLevel, for conversationID: UUID?) {}
        var globalLanguage: ConversationLanguage { .english }
        func setGlobalLanguage(_ language: ConversationLanguage) {}
        func language(for conversationID: UUID?) -> ConversationLanguage { .english }
        func setLanguage(_ language: ConversationLanguage, for conversationID: UUID?) {}
    }

    // MARK: - ConversationStateProviding

    /// 支持 emit 的会话状态 Provider。
    @MainActor
    final class StubConversationStateProvider: ConversationStateProviding {
        var snapshots: [UUID: ConversationStateSnapshot] = [:]
        private var observers: [UUID: (ConversationStateEvent) -> Void] = [:]
        private var handles: [UUID: CountingStateHandle] = [:]

        init(snapshots: [UUID: ConversationStateSnapshot] = [:]) {
            self.snapshots = snapshots
        }

        var states: [UUID: ConversationStateSnapshot] { snapshots }

        func state(for conversationID: UUID) -> ConversationStateSnapshot {
            snapshots[conversationID] ?? ConversationStateSnapshot(conversationID: conversationID)
        }

        func addConversationStateObserver(
            _ callback: @escaping (ConversationStateEvent) -> Void
        ) -> any ConversationStateObserverHandle {
            let id = UUID()
            observers[id] = callback
            let handle = CountingStateHandle()
            handles[id] = handle
            return handle
        }

        /// 广播事件后清理已注销的观察者。
        func emit(_ event: ConversationStateEvent) {
            let cancelled = handles.filter { $0.value.isCancelled }.keys
            for id in cancelled {
                observers[id] = nil
                handles[id] = nil
            }
            observers.values.forEach { $0(event) }
        }

        func cancelAll() {
            for handle in handles.values { handle.cancel() }
            handles.removeAll()
            observers.removeAll()
        }

        var observerCount: Int { observers.count }
    }

    @MainActor
    final class CountingStateHandle: ConversationStateObserverHandle {
        private(set) var isCancelled = false
        func cancel() { isCancelled = true }
    }

    // MARK: - MessageStreamingProviding

    /// 只驱动 stage 与事件的流式 Provider。
    @MainActor
    final class StubStreamingProvider: MessageStreamingProviding {
        var stages: [UUID: MessageStreamingStage] = [:]
        private var observers: [UUID: (MessageStreamingChange) -> Void] = [:]
        private var handles: [UUID: CountingStreamingHandle] = [:]

        func streamingMessage(for conversationID: UUID) -> Message? { nil }
        func stage(for conversationID: UUID) -> MessageStreamingStage {
            stages[conversationID] ?? .idle
        }
        func start(conversationID: UUID) { stages[conversationID] = .sending }
        func appendContent(_ content: String, conversationID: UUID) { stages[conversationID] = .generating }
        func appendThinking(_ content: String, conversationID: UUID) { stages[conversationID] = .thinking }
        func end(conversationID: UUID) { stages[conversationID] = .idle }

        func addMessageStreamingObserver(
            _ callback: @escaping (MessageStreamingChange) -> Void
        ) -> any MessageStreamingObserverHandle {
            let id = UUID()
            observers[id] = callback
            let handle = CountingStreamingHandle()
            handles[id] = handle
            return handle
        }

        func emitStage(_ stage: MessageStreamingStage, for conversationID: UUID) {
            stages[conversationID] = stage
            observers.values.forEach { $0(.updated(conversationID)) }
        }

        func cancelAll() {
            for handle in handles.values { handle.cancel() }
            handles.removeAll()
            observers.removeAll()
        }
    }

    @MainActor
    final class CountingStreamingHandle: MessageStreamingObserverHandle {
        private(set) var isCancelled = false
        func cancel() { isCancelled = true }
    }

    // MARK: - DeveloperModeProviding

    @MainActor
    final class StubDeveloperModeProvider: DeveloperModeProviding {
        var enabled: Bool
        var handle = CountingDeveloperModeHandle()
        private var observer: ((DeveloperModeProvidingEvent) -> Void)?

        init(enabled: Bool = false) { self.enabled = enabled }

        var isEnabled: Bool { enabled }
        func setEnabled(_ enabled: Bool) {
            guard self.enabled != enabled else { return }
            self.enabled = enabled
            observer?(.enabledChanged(enabled))
        }
        func toggle() { setEnabled(!enabled) }

        func addObserver(
            _ callback: @escaping (DeveloperModeProvidingEvent) -> Void
        ) -> any DeveloperModeProvidingObserverHandle {
            observer = callback
            handle.onCancel = { [weak self] in self?.observer = nil }
            return handle
        }
    }

    // MARK: - MessageRenderingProviding

    /// 按 `canRender` 委托给渲染器列表的渲染 Provider。
    @MainActor
    final class StubRenderingProvider: MessageRenderingProviding {
        private(set) var renderers: [MessageRendererItem] = []

        var allRenderers: [MessageRendererItem] { renderers }

        func register(_ renderer: MessageRendererItem) {
            renderers.removeAll { $0.id == renderer.id }
            renderers.append(renderer)
        }

        func unregister(id: String) {
            renderers.removeAll { $0.id == id }
        }

        func renderer(for message: Message) -> MessageRendererItem? {
            renderers.first { $0.canRender(message) }
        }
    }

    /// 构造一个只渲染指定消息的 renderer item。
    @MainActor
    func makeRenderer(
        id: String,
        matching predicate: @escaping @Sendable (Message) -> Bool
    ) -> MessageRendererItem {
        MessageRendererItem(id: id, order: 0, canRender: predicate) { _, _ in
            AnyView(EmptyView())
        }
    }

    // MARK: - ChatSectionProviding

    /// 记录 add/remove/refresh 调用的 ChatSection 替身。
    ///
    /// 协议成员较多，未覆盖部分走 `ChatSectionProviding` 的默认扩展。
    @MainActor
    final class StubChatSectionProvider: ChatSectionProviding {
        private(set) var addedItems: [ChatSectionItem] = []
        private(set) var removedItemIDs: [String] = []
        private(set) var refreshCount = 0
        private(set) var barItems: [ChatSectionBarItem] = []

        var isVisible = true
        var isContextActive = true
        var headerVisible = true

        func addItems(_ items: [ChatSectionItem]) { addedItems.append(contentsOf: items) }
        func removeItem(id: String) { removedItemIDs.append(id) }
        func refreshItems() { refreshCount += 1 }
        func addBarItems(_ items: [ChatSectionBarItem]) { barItems.append(contentsOf: items) }
        func removeBarItem(id: String) {
            barItems.removeAll { $0.id == id }
        }
        func setVisible(_ visible: Bool) { isVisible = visible }
        func setContextActive(_ active: Bool) { isContextActive = active }

        func addObserver(
            _ callback: @escaping (ChatSectionProvidingEvent) -> Void
        ) -> any ChatSectionProvidingObserverHandle {
            CountingChatSectionHandle()
        }

        func activateWidthProfile(
            ownerID: String,
            recommended: ChatSectionWidth,
            store: (any ChatSectionWidthStoring)?
        ) {}

        func deactivateWidthProfile(ownerID: String) {}
        func saveCurrentWidth(_ width: CGFloat) {}
        func makeChatSectionView() -> AnyView { AnyView(EmptyView()) }

        /// 当前是否仍持有由某 id 注册的 item。
        func hasItem(id: String) -> Bool {
            addedItems.contains { $0.id == id } && !removedItemIDs.contains(id)
        }
    }

    // MARK: - AgentLoopProviding

    /// 只实现 `state(for:)` 的 AgentLoop Provider。
    ///
    /// 其余回合生命周期成员对消息列表无意义，一律返回空值。
    @MainActor
    final class StubAgentLoopProvider: AgentLoopProviding {
        var stateToReturn: AgentLoopState
        init(state: AgentLoopState = .idle) { stateToReturn = state }

        func state(for conversationID: UUID) -> AgentLoopState { stateToReturn }

        func addAgentLoopObserver(
            _ callback: @escaping (AgentLoopEvent) -> Void
        ) -> any AgentLoopObserverHandle {
            CountingAgentLoopHandle()
        }

        func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome { .cancelled }
        func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome { .cancelled }
        func cancelTurn(in conversationID: UUID) {}
        func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
        func lastFailure(for conversationID: UUID) -> AgentLoopFailure? { nil }
        func isRunning(for conversationID: UUID) -> Bool { stateToReturn == .running }
        func currentTurnID(for conversationID: UUID) -> UUID? { nil }
        func isAutoReplySuppressed(for conversationID: UUID) -> Bool { false }
        func setAutoReplySuppressed(_ suppressed: Bool, for conversationID: UUID) {}
        func retryTurn(in conversationID: UUID, after failedTurnID: UUID) async throws -> AgentLoopOutcome { .cancelled }
        func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
    }

    @MainActor
    final class CountingAgentLoopHandle: AgentLoopObserverHandle {
        private(set) var cancelCount = 0
        func cancel() { cancelCount += 1 }
    }
}
