import Foundation
import KitLLM
import ProviderConversation
import ProviderLLMManager
import ProviderMessage

/// 自动标题链路测试共用的 in-memory Provider 替身。
///
/// `TitleService` 只用到三个 Provider 的一小部分能力，因此替身只实现被
/// 观测的成员，其余全部走协议默认扩展。测试目标是「事件 / 消息 → 标题决策」
/// 的转发链路，与真实持久化实现无关。
enum TitleTestDoubles {

    // MARK: - Handles

    /// 可计数的注销令牌，用于验证 Observer 确实释放了订阅。
    @MainActor
    final class CountingConversationHandle: ConversationObserverHandle {
        private(set) var cancelCount = 0
        var onCancel: (() -> Void)?
        func cancel() {
            cancelCount += 1
            onCancel?()
        }
    }

    /// 消息插入订阅的注销令牌。
    ///
    /// `onCancel` 让持有 handle 的替身在 `cancel()` 时清掉回调，
    /// 否则替身仍会向已注销的闭包派发消息，测试会看到"幽灵调用"。
    @MainActor
    final class CountingMessageInsertedHandle: MessageInsertedObserverHandle {
        private(set) var cancelCount = 0
        var onCancel: (() -> Void)?
        func cancel() {
            cancelCount += 1
            onCancel?()
        }
    }

    /// 选中会话订阅的空实现；标题链路只读 `currentTitle`，不需要该事件。
    @MainActor
    final class NoopSelectedHandle: SelectedConversationObserverHandle {
        func cancel() {}
    }

    // MARK: - MessageManaging

    /// 支持手动 emit 消息插入事件的消息管理器。
    ///
    /// 只实现 `TitleService` 真正读到的成员：`firstUserMessage` 与
    /// `addMessageInsertedObserver`，其余走协议默认实现（由 `messages(for:)` 派生）。
    @MainActor
    final class StubMessageManager: MessageManaging {
        private(set) var stored: [Message] = []
        let insertHandle = CountingMessageInsertedHandle()
        /// 便于断言「取首条用户消息」被调用了几次。
        private(set) var firstUserMessageCallCount = 0
        private var observer: ((Message, UUID) -> Void)?

        init(messages: [Message] = []) { stored = messages }

        func messages(for conversationID: UUID) -> [Message] {
            stored.filter { $0.conversationID == conversationID }
        }

        func firstUserMessage(in conversationID: UUID) async -> Message? {
            firstUserMessageCallCount += 1
            return messages(for: conversationID).first {
                $0.role == .user && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
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
        func addMessageInsertedObserver(
            _ callback: @escaping (Message, UUID) -> Void
        ) -> any MessageInsertedObserverHandle {
            observer = callback
            insertHandle.onCancel = { [weak self] in self?.observer = nil }
            return insertHandle
        }

        // MARK: Test driving

        /// 模拟「消息落库后 Provider 广播插入事件」。
        ///
        /// 默认同时把消息写进内存，让 `firstUserMessage` 能查到；
        /// 传 `persist: false` 可模拟广播早于落库的时序。
        func emitInserted(_ message: Message, persist: Bool = true) {
            if persist { insertMessage(message, to: message.conversationID) }
            observer?(message, message.conversationID)
        }

        var isObserving: Bool { observer != nil }
    }

    // MARK: - ConversationManaging

    /// 支持手动 emit `ConversationEvent` 的会话管理器。
    ///
    /// 未覆盖的成员一律走 `ConversationManaging` 的默认扩展。
    @MainActor
    final class StubConversationManager: ConversationManaging {
        private(set) var summaries: [ConversationSummary]
        var selected: UUID?
        let conversationHandle = CountingConversationHandle()
        private var conversationObserver: ((ConversationEvent) -> Void)?
        /// 强制 `updateConversationTitle` 返回 false，用于模拟写库失败。
        var failTitleUpdate = false
        /// 记录实际落库的标题，便于断言"没有发生写入"。
        private(set) var titleUpdateRequests: [(title: String, id: UUID)] = []

        init(selected: UUID? = nil, summaries: [ConversationSummary] = []) {
            self.selected = selected
            self.summaries = summaries
        }

        var conversations: [ConversationSummary] { summaries }
        var selectedConversationID: UUID? { selected }
        var currentTitle: String {
            summaries.first(where: { $0.id == selected })?.title ?? ""
        }
        var dataDirectory: URL { URL(fileURLWithPath: "/tmp/PluginConversationTitleTests") }

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

        func selectConversation(id: UUID) { selected = id }
        func deselectConversation() { selected = nil }
        func deleteConversation(id: UUID) { summaries.removeAll { $0.id == id } }

        func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool {
            titleUpdateRequests.append((title, conversationID))
            guard !failTitleUpdate else { return false }
            guard let index = summaries.firstIndex(where: { $0.id == conversationID }) else { return false }
            summaries[index].title = title
            return true
        }

        func markConversationActive(id: UUID, messageDate: Date) {}
        func isSending(for conversationID: UUID?) -> Bool { false }

        func providerID(for conversationID: UUID?) -> String? { nil }
        func modelName(for conversationID: UUID?) -> String? { nil }
        func selectProvider(id: String, model: String?, for conversationID: UUID?) {}

        // 偏好设置：标题链路不关心，统一给固定值即可。
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
            NoopSelectedHandle()
        }

        @discardableResult
        func addConversationObserver(
            _ callback: @escaping (ConversationEvent) -> Void
        ) -> any ConversationObserverHandle {
            conversationObserver = callback
            conversationHandle.onCancel = { [weak self] in self?.conversationObserver = nil }
            return conversationHandle
        }

        func transferObservers(to replacement: any ConversationManaging) {}

        // MARK: Test driving

        func emit(_ event: ConversationEvent) { conversationObserver?(event) }
        var isObserving: Bool { conversationObserver != nil }

        func title(of id: UUID) -> String? {
            summaries.first(where: { $0.id == id })?.title
        }

        func appendSummary(id: UUID, title: String?) {
            summaries.append(ConversationSummary(
                id: id,
                title: title,
                createdAt: Date(),
                updatedAt: Date()
            ))
        }
    }

    // MARK: - LLMManaging

    /// 记录请求并返回预设标题的 LLM 管理器。
    ///
    /// `LLMManaging` 继承 `SuperLLMProvider`，后者为绝大多数成员提供了默认实现，
    /// 这里只需覆盖 `complete(_:)` 与两个查询成员。
    @MainActor
    final class StubLLMManager: LLMManaging {
        /// 返回给 `complete` 的标题文本。
        var responseContent: String
        /// 置为非 nil 时 `complete` 抛出该错误，用于验证失败时不写库。
        var completionError: Error?
        /// 记录收到的请求，用于断言 prompt 组装与模型路由。
        private(set) var receivedRequests: [LLMRequest] = []

        init(responseContent: String = "生成的标题", completionError: Error? = nil) {
            self.responseContent = responseContent
            self.completionError = completionError
        }

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            receivedRequests.append(request)
            if let completionError { throw completionError }
            return LLMResponse(content: responseContent)
        }

        var providerCount: Int { 0 }
        func allProviders() -> [any SuperLLMProvider] { [] }
        func provider(id: String) -> (any SuperLLMProvider)? { nil }
        func register(_ provider: any SuperLLMProvider) throws {}
        func unregister(id: String) {}
        var selectedProviderID: String? { nil }
        var selectedModel: String? { nil }
        func models(for providerID: String) -> [String] { [] }
        func select(providerID: String, model: String?, reason: ModelSelectionReason) {}

        var providerID: String { "stub-llm" }
        var providerInfo: LLMProviderInfo {
            LLMProviderInfo(
                id: "stub-llm",
                displayName: "Stub LLM",
                defaultModel: "stub-model",
                models: [LLMModelInfo(id: "stub-model")]
            )
        }
    }
}

/// 用于断言 LLM 抛错的哨兵错误。
struct StubLLMError: Error, Equatable {
    let reason: String
}
