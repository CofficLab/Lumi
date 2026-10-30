import Foundation
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import SwiftUI

/// 缓存命中率插件测试共用的 in-memory Provider 替身。
///
/// 目标是把「Provider 事件 → 工具栏状态」的转发链路测清楚，与真实持久化实现无关。
/// 三个 Provider 协议都提供了大量默认实现，因此替身只覆盖被观测的成员。
enum CacheHitRateTestDoubles {

    // MARK: - Handles

    /// 可计数的选中会话订阅令牌。
    @MainActor
    final class CountingSelectedHandle: SelectedConversationObserverHandle {
        private(set) var cancelCount = 0
        var onCancel: (() -> Void)?
        func cancel() {
            cancelCount += 1
            onCancel?()
        }
    }

    /// 可计数的消息变化订阅令牌。
    @MainActor
    final class CountingMessageChangeHandle: MessageChangeObserverHandle {
        private(set) var cancelCount = 0
        var onCancel: (() -> Void)?
        func cancel() {
            cancelCount += 1
            onCancel?()
        }
    }

    // MARK: - MessageManaging

    /// 支持手动 emit `MessageChange` 的消息管理器。
    @MainActor
    final class StubMessageManager: MessageManaging {
        private(set) var stored: [Message] = []
        let changeHandle = CountingMessageChangeHandle()
        private var changeObserver: ((MessageChange) -> Void)?

        init(messages: [Message] = []) { stored = messages }

        func messages(for conversationID: UUID) -> [Message] {
            stored.filter { $0.conversationID == conversationID }
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

        @discardableResult
        func addMessageChangeObserver(
            _ callback: @escaping (MessageChange) -> Void
        ) -> any MessageChangeObserverHandle {
            changeObserver = callback
            changeHandle.onCancel = { [weak self] in self?.changeObserver = nil }
            return changeHandle
        }

        // MARK: Test driving

        /// 广播一条消息变化事件。
        func emit(_ change: MessageChange) { changeObserver?(change) }

        var isObserving: Bool { changeObserver != nil }
    }

    // MARK: - ConversationManaging

    /// 支持手动切换选中态的会话管理器。
    @MainActor
    final class StubConversationManager: ConversationManaging {
        private(set) var summaries: [ConversationSummary]
        var selected: UUID?
        let selectedHandle = CountingSelectedHandle()
        private var selectedObserver: ((UUID?) -> Void)?

        init(selected: UUID? = nil, summaries: [ConversationSummary] = []) {
            self.selected = selected
            self.summaries = summaries
        }

        var conversations: [ConversationSummary] { summaries }
        var selectedConversationID: UUID? { selected }
        var currentTitle: String { summaries.first(where: { $0.id == selected })?.title ?? "" }
        var dataDirectory: URL { URL(fileURLWithPath: "/tmp/PluginConversationCacheHitRateTests") }

        func createConversation(
            title: String?,
            projectPath: String?,
            providerID: String?,
            modelName: String?
        ) throws -> UUID {
            let id = UUID()
            summaries.append(ConversationSummary(
                id: id,
                title: title,
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

        func providerID(for conversationID: UUID?) -> String? { nil }
        func modelName(for conversationID: UUID?) -> String? { nil }
        func selectProvider(id: String, model: String?, for conversationID: UUID?) {}

        var globalVerbosity: ResponseVerbosity { .brief }
        func setGlobalVerbosity(_ verbosity: ResponseVerbosity) {}
        func verbosity(for conversationID: UUID?) -> ResponseVerbosity { .brief }
        func setVerbosity(_ verbosity: ResponseVerbosity, for conversationID: UUID?) {}

        var globalReasoningEffort: ReasoningEffort? { nil }
        func setGlobalReasoningEffort(_ effort: ReasoningEffort?) {}
        func reasoningEffort(for conversationID: UUID?) -> ReasoningEffort { .medium }
        func reasoningEffortOptional(for conversationID: UUID?) -> ReasoningEffort? { nil }
        func setReasoningEffort(_ effort: ReasoningEffort, for conversationID: UUID?) {}
        func clearReasoningEffort(for conversationID: UUID?) {}

        var globalAutomationLevel: AutomationLevel { .chat }
        func setGlobalAutomationLevel(_ level: AutomationLevel) {}
        func automationLevel(for conversationID: UUID?) -> AutomationLevel { .chat }
        func setAutomationLevel(_ level: AutomationLevel, for conversationID: UUID?) {}

        var globalLanguage: ConversationLanguage { .english }
        func setGlobalLanguage(_ language: ConversationLanguage) {}
        func language(for conversationID: UUID?) -> ConversationLanguage { .english }
        func setLanguage(_ language: ConversationLanguage, for conversationID: UUID?) {}

        @discardableResult
        func addSelectedConversationObserver(
            _ callback: @escaping (UUID?) -> Void
        ) -> any SelectedConversationObserverHandle {
            selectedObserver = callback
            selectedHandle.onCancel = { [weak self] in self?.selectedObserver = nil }
            return selectedHandle
        }

        // MARK: Test driving

        /// 模拟 Provider 广播选中态变化。
        func emitSelection(_ id: UUID?) {
            selected = id
            selectedObserver?(id)
        }

        var isObserving: Bool { selectedObserver != nil }
    }

    // MARK: - ChatSectionProviding

    /// 记录工具栏注册 / 移除调用的 ChatSection 替身。
    @MainActor
    final class StubChatSectionProvider: ChatSectionProviding {
        private(set) var addedBarItems: [ChatSectionBarItem] = []
        private(set) var removedBarItemIDs: [String] = []

        var isVisible = true
        var isContextActive = true

        func addItems(_ items: [ChatSectionItem]) {}
        func removeItem(id: String) {}

        func addBarItems(_ items: [ChatSectionBarItem]) {
            addedBarItems.append(contentsOf: items)
        }

        func removeBarItem(id: String) {
            removedBarItemIDs.append(id)
            addedBarItems.removeAll { $0.id == id }
        }

        func setVisible(_ visible: Bool) { isVisible = visible }
        func setContextActive(_ active: Bool) { isContextActive = active }

        func makeChatSectionView() -> AnyView { AnyView(EmptyView()) }

        var barItemIDs: [String] { addedBarItems.map(\.id) }
    }
}
