import Foundation
import KitLLM
import ProviderConversation
import ProviderLLMManager
import ProviderMessage
import Testing
@testable import PluginModelSelector

/// 「用户切换模型 → 会话时间线插入一条时间线消息」的行为。
///
/// ## 为什么要有这组用例
///
/// 模型切换是用户明确表达的意图，却原本没有任何可见反馈：按钮标签变了，
/// 但对话里看不出「接下来的回答换了个模型」，历史会话重新打开时更是一片空白。
///
/// 这组用例钉死三件事：
/// 1. 切换确实产生一条时间线消息，且带旧/新供应商与模型；
/// 2. 该消息是**时间线事件**，不会回流到 LLM 上下文；
/// 3. 边界正确：没换模型不写、没有会话不写。
@MainActor
@Suite(.serialized)
struct ModelSwitchTimelineTests {

    /// 记录插入的消息，替代真实 `MessageManaging`。
    private final class RecordingMessageManager: MessageManaging {
        private(set) var inserted: [(message: Message, conversationID: UUID)] = []

        func messages(for conversationID: UUID) -> [Message] { [] }
        func messagesSnapshot(in conversationID: UUID) async -> [Message] { [] }
        func firstUserMessage(in conversationID: UUID) async -> Message? { nil }
        func messagesForLLM(in conversationID: UUID) async -> [Message] { [] }
        func messagePage(
            for conversationID: UUID,
            limit: Int,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) -> [Message] { [] }
        func messagePageAsync(
            for conversationID: UUID,
            limit: Int,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) async -> [Message] { [] }
        func hasEarlierMessages(
            for conversationID: UUID,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) -> Bool { false }
        func hasEarlierMessagesAsync(
            for conversationID: UUID,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) async -> Bool { false }
        func message(id: UUID, in conversationID: UUID) -> Message? { nil }
        func lastMessage(in conversationID: UUID) -> Message? { nil }
        func messageCount(for conversationID: UUID) -> Int { 0 }
        func dailyMessageCounts(since: Date) -> [Date: Int] { [:] }
        func dailyMessageCountsAsync(since: Date) async -> [Date: Int] { [:] }
        func dailyTokenCounts(since: Date) -> [Date: Int] { [:] }
        func dailyTokenCountsAsync(since: Date) async -> [Date: Int] { [:] }
        func insertMessage(_ message: Message, to conversationID: UUID) {
            inserted.append((message, conversationID))
        }
        func updateMessage(id: UUID, in conversationID: UUID, content: String) {}
        func deleteMessage(id: UUID, in conversationID: UUID) {}
        func clearMessages(in conversationID: UUID) {}
        func updateToolCallResult(
            _ result: MessageToolResult,
            toolCallID: String,
            assistantMessageID: UUID,
            in conversationID: UUID,
            authorizationState: String?
        ) {}
    }

    /// 会话写入**静默失败**的替身。
    ///
    /// 模拟真实故障：会话已被整表重载替换、不在缓存数组里，此时
    /// `selectModel` 的 guard 会直接返回 —— 模型其实没换，但调用方
    /// 拿不到任何失败信号。若此时仍写入「已切换」的时间线消息就是误导。
    ///
    /// 只覆盖与模型绑定相关的两个方法，其余原样转发给内部实现。
    private final class SilentConversationManager: ConversationManaging {
        private let base: DefaultConversationManager
        private let conversationID: UUID

        init(conversationID: UUID) {
            self.base = DefaultConversationManager()
            self.conversationID = conversationID
        }

        var selectedConversationID: UUID? { conversationID }

        /// 永远读不到模型：模拟写入没生效。
        func modelID(for conversationID: UUID?) -> String? { nil }

        /// 什么都不做：静默失败。
        func selectModel(id: String, for conversationID: UUID?) {}

        // MARK: - 转发其余成员

        var conversations: [ConversationSummary] { base.conversations }
        var sortedConversations: [ConversationSummary] { base.sortedConversations }
        var currentTitle: String { base.currentTitle }
        var isLoadingConversations: Bool { base.isLoadingConversations }
        var dataDirectory: URL { base.dataDirectory }

        func fetchConversationPage(
            limit: Int,
            beforeUpdatedAt: Date?,
            beforeID: UUID?
        ) async -> [ConversationSummary] {
            await base.fetchConversationPage(limit: limit, beforeUpdatedAt: beforeUpdatedAt, beforeID: beforeID)
        }
        func fetchConversationPage(
            limit: Int,
            beforeUpdatedAt: Date?,
            beforeID: UUID?,
            includingChildConversations: Bool
        ) async -> [ConversationSummary] {
            await base.fetchConversationPage(
                limit: limit,
                beforeUpdatedAt: beforeUpdatedAt,
                beforeID: beforeID,
                includingChildConversations: includingChildConversations
            )
        }
        func fetchConversationPage(
            limit: Int,
            beforeUpdatedAt: Date?,
            beforeID: UUID?,
            includingChildConversations: Bool,
            projectPath: String
        ) async -> [ConversationSummary] {
            await base.fetchConversationPage(
                limit: limit,
                beforeUpdatedAt: beforeUpdatedAt,
                beforeID: beforeID,
                includingChildConversations: includingChildConversations,
                projectPath: projectPath
            )
        }
        func fetchConversation(id: UUID) async -> ConversationSummary? {
            await base.fetchConversation(id: id)
        }
        func untitledConversationIDs(limit: Int) async -> [UUID] {
            await base.untitledConversationIDs(limit: limit)
        }
        func conversationCount(projectPath: String?) async -> Int {
            await base.conversationCount(projectPath: projectPath)
        }
        func conversationCount(projectPath: String?, includingChildConversations: Bool) async -> Int {
            await base.conversationCount(
                projectPath: projectPath,
                includingChildConversations: includingChildConversations
            )
        }
        func conversationProjectCount() async -> Int {
            await base.conversationProjectCount()
        }
        func fetchDailyCountSeries(
            days: Int,
            projectPath: String?,
            includingChildConversations: Bool
        ) async -> ConversationDailyCountSeries {
            await base.fetchDailyCountSeries(
                days: days,
                projectPath: projectPath,
                includingChildConversations: includingChildConversations
            )
        }
        func conversationCount(
            createdBefore cutoff: Date,
            projectPath: String?,
            includingChildConversations: Bool
        ) async -> Int {
            await base.conversationCount(
                createdBefore: cutoff,
                projectPath: projectPath,
                includingChildConversations: includingChildConversations
            )
        }
        func deleteConversations(
            createdBefore cutoff: Date,
            projectPath: String?,
            includingChildConversations: Bool
        ) async -> [UUID] {
            await base.deleteConversations(
                createdBefore: cutoff,
                projectPath: projectPath,
                includingChildConversations: includingChildConversations
            )
        }
        func conversationIDs(projectPath: String, updatedSince: Date?) async -> [String] {
            await base.conversationIDs(projectPath: projectPath, updatedSince: updatedSince)
        }
        func createConversation(
            title: String?,
            projectPath: String?,
            providerID: String?,
            modelName: String?
        ) throws -> UUID {
            try base.createConversation(
                title: title,
                projectPath: projectPath,
                providerID: providerID,
                modelName: modelName
            )
        }
        func createConversation(title: String?, projectPath: String?, modelID: String?) throws -> UUID {
            try base.createConversation(title: title, projectPath: projectPath, modelID: modelID)
        }
        func selectConversation(id: UUID) { base.selectConversation(id: id) }
        func deselectConversation() { base.deselectConversation() }
        func addSelectedConversationObserver(
            _ callback: @escaping (UUID?) -> Void
        ) -> any SelectedConversationObserverHandle {
            base.addSelectedConversationObserver(callback)
        }
        func addConversationObserver(
            _ callback: @escaping (ConversationEvent) -> Void
        ) -> any ConversationObserverHandle {
            base.addConversationObserver(callback)
        }
        func transferObservers(to replacement: any ConversationManaging) {
            base.transferObservers(to: replacement)
        }
        func deleteConversation(id: UUID) { base.deleteConversation(id: id) }
        func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool {
            base.updateConversationTitle(title, for: conversationID)
        }
        func markConversationActive(id: UUID, messageDate: Date) {
            base.markConversationActive(id: id, messageDate: messageDate)
        }
        func isSending(for conversationID: UUID?) -> Bool {
            base.isSending(for: conversationID)
        }
        func providerID(for conversationID: UUID?) -> String? {
            base.providerID(for: conversationID)
        }
        func modelName(for conversationID: UUID?) -> String? {
            base.modelName(for: conversationID)
        }
        func selectProvider(id: String, model: String?, for conversationID: UUID?) {
            base.selectProvider(id: id, model: model, for: conversationID)
        }

        func createConversation(
            title: String?,
            projectPath: String?,
            providerID: String?,
            modelName: String?,
            parentConversationID: UUID?
        ) throws -> UUID {
            try base.createConversation(
                title: title,
                projectPath: projectPath,
                providerID: providerID,
                modelName: modelName,
                parentConversationID: parentConversationID
            )
        }

        // MARK: - 偏好设置（与本用例无关，原样转发）

        var globalVerbosity: ResponseVerbosity { base.globalVerbosity }
        func setGlobalVerbosity(_ verbosity: ResponseVerbosity) {
            base.setGlobalVerbosity(verbosity)
        }
        func setVerbosity(_ verbosity: ResponseVerbosity, for conversationID: UUID?) {
            base.setVerbosity(verbosity, for: conversationID)
        }
        func verbosity(for conversationID: UUID?) -> ResponseVerbosity {
            base.verbosity(for: conversationID)
        }
        var globalReasoningEffort: ReasoningEffort? { base.globalReasoningEffort }
        func setGlobalReasoningEffort(_ effort: ReasoningEffort?) {
            base.setGlobalReasoningEffort(effort)
        }
        func reasoningEffort(for conversationID: UUID?) -> ReasoningEffort {
            base.reasoningEffort(for: conversationID)
        }
        func reasoningEffortOptional(for conversationID: UUID?) -> ReasoningEffort? {
            base.reasoningEffortOptional(for: conversationID)
        }
        func setReasoningEffort(_ effort: ReasoningEffort, for conversationID: UUID?) {
            base.setReasoningEffort(effort, for: conversationID)
        }
        func clearReasoningEffort(for conversationID: UUID?) {
            base.clearReasoningEffort(for: conversationID)
        }
        var globalAutomationLevel: AutomationLevel { base.globalAutomationLevel }
        func setGlobalAutomationLevel(_ level: AutomationLevel) {
            base.setGlobalAutomationLevel(level)
        }
        func automationLevel(for conversationID: UUID?) -> AutomationLevel {
            base.automationLevel(for: conversationID)
        }
        func setAutomationLevel(_ level: AutomationLevel, for conversationID: UUID?) {
            base.setAutomationLevel(level, for: conversationID)
        }
        var globalLanguage: ConversationLanguage { base.globalLanguage }
        func setGlobalLanguage(_ language: ConversationLanguage) {
            base.setGlobalLanguage(language)
        }
        func language(for conversationID: UUID?) -> ConversationLanguage {
            base.language(for: conversationID)
        }
        func setLanguage(_ language: ConversationLanguage, for conversationID: UUID?) {
            base.setLanguage(language, for: conversationID)
        }
    }

    /// 提供两个模型的最小供应商。
    private final class TwoModelProvider: SuperLLMProvider, @unchecked Sendable {        let providerID = "test-provider"
        let providerInfo = LLMProviderInfo(
            id: "test-provider",
            displayName: "Test Provider",
            defaultModel: "model-a",
            models: [
                LLMModelInfo(id: "model-a", displayName: "Model A"),
                LLMModelInfo(id: "model-b", displayName: "Model B"),
            ]
        )

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            LLMResponse(content: "")
        }
    }

    /// 隔离的 `UserDefaults` 域，供 `DefaultLLMManager` 读写选中态。
    private static func makeIsolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "com.coffic.lumi.test.modelswitch.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        return (defaults, suiteName)
    }

    /// 构造一个带时间线记录器的适配器。
    private static func makeAdapter(
        conversations: (any ConversationManaging)?,
        llmManager: any LLMManaging,
        recorder: ModelSwitchTimelineRecorder?
    ) -> ModelSelectionCapabilityAdapter {
        ModelSelectionCapabilityAdapter(
            conversations: conversations,
            llmManager: llmManager,
            timelineRecorder: recorder
        )
    }

    @Test("切换模型后向会话插入一条时间线消息，含旧/新供应商与模型")
    func insertsTimelineMessageOnSwitch() throws {
        let conversations = DefaultConversationManager()
        let conversationID = try conversations.createConversation(
            title: "switch",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )

        let (defaults, suiteName) = Self.makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let previous = LLMManagerUserDefaults.current
        LLMManagerUserDefaults.current = defaults
        defer { LLMManagerUserDefaults.current = previous }

        let llm = DefaultLLMManager()
        try llm.register(TwoModelProvider())

        // 先把会话钉到 model-a，作为「切换前」的状态。
        let modelA = try #require(LLMModelID(providerID: "test-provider", modelID: "model-a"))
        let modelB = try #require(LLMModelID(providerID: "test-provider", modelID: "model-b"))
        conversations.selectModel(id: modelA.rawValue, for: conversationID)

        let messages = RecordingMessageManager()
        let adapter = Self.makeAdapter(
            conversations: conversations,
            llmManager: llm,
            recorder: ModelSwitchTimelineRecorder(messages: messages)
        )

        adapter.select(modelID: modelB.rawValue)

        #expect(messages.inserted.count == 1, "切换模型应插入恰好一条时间线消息")
        let entry = try #require(messages.inserted.first)
        #expect(entry.conversationID == conversationID)

        let message = entry.message
        #expect(message.role == .system)
        #expect(message.metadata[MessageTimelineEvent.metadataKey] == MessageTimelineEvent.modelSwitched)
        #expect(message.renderKind == MessageTimelineEvent.modelSwitchedRenderKind)
        #expect(
            message.metadata[MessageTimelineEvent.modelSwitchedFromModelNameKey] == "model-a",
            "应记录切换前的模型"
        )
        #expect(
            message.metadata[MessageTimelineEvent.modelSwitchedToModelNameKey] == "model-b",
            "应记录切换后的模型"
        )
        #expect(
            message.metadata[MessageTimelineEvent.modelSwitchedFromProviderIDKey] == "test-provider"
        )
        #expect(
            message.metadata[MessageTimelineEvent.modelSwitchedToProviderIDKey] == "test-provider"
        )
    }

    @Test("模型切换消息是时间线事件，不回流 LLM 上下文")
    func timelineMessageDoesNotLeakIntoLLMContext() throws {
        let conversations = DefaultConversationManager()
        _ = try conversations.createConversation(
            title: "leak",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )

        let (defaults, suiteName) = Self.makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let previous = LLMManagerUserDefaults.current
        LLMManagerUserDefaults.current = defaults
        defer { LLMManagerUserDefaults.current = previous }

        let llm = DefaultLLMManager()
        try llm.register(TwoModelProvider())
        let modelB = try #require(LLMModelID(providerID: "test-provider", modelID: "model-b"))

        let messages = RecordingMessageManager()
        let adapter = Self.makeAdapter(
            conversations: conversations,
            llmManager: llm,
            recorder: ModelSwitchTimelineRecorder(messages: messages)
        )
        adapter.select(modelID: modelB.rawValue)

        let message = try #require(messages.inserted.first?.message)
        #expect(MessageTimelineEvent.isModelSwitched(message))
        #expect(
            MessageTimelineEvent.isTimelineEvent(message),
            "模型切换消息必须被 LLM 上下文过滤掉"
        )
    }

    @Test("切到同一个模型不产生时间线消息")
    func sameModelProducesNoTimelineMessage() throws {
        let conversations = DefaultConversationManager()
        let conversationID = try conversations.createConversation(
            title: "same",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )

        let (defaults, suiteName) = Self.makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let previous = LLMManagerUserDefaults.current
        LLMManagerUserDefaults.current = defaults
        defer { LLMManagerUserDefaults.current = previous }

        let llm = DefaultLLMManager()
        try llm.register(TwoModelProvider())
        let modelA = try #require(LLMModelID(providerID: "test-provider", modelID: "model-a"))
        conversations.selectModel(id: modelA.rawValue, for: conversationID)

        let messages = RecordingMessageManager()
        let adapter = Self.makeAdapter(
            conversations: conversations,
            llmManager: llm,
            recorder: ModelSwitchTimelineRecorder(messages: messages)
        )
        adapter.select(modelID: modelA.rawValue)

        #expect(
            messages.inserted.isEmpty,
            "切到同一个模型不算切换，不应产生时间线消息"
        )
    }

    @Test("没有选中会话时不产生时间线消息（只改全局默认）")
    func noConversationProducesNoTimelineMessage() throws {
        let (defaults, suiteName) = Self.makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let previous = LLMManagerUserDefaults.current
        LLMManagerUserDefaults.current = defaults
        defer { LLMManagerUserDefaults.current = previous }

        let llm = DefaultLLMManager()
        try llm.register(TwoModelProvider())

        let messages = RecordingMessageManager()
        // 无会话：模型只改全局默认，不存在「这个会话换了模型」可写。
        let adapter = Self.makeAdapter(
            conversations: nil,
            llmManager: llm,
            recorder: ModelSwitchTimelineRecorder(messages: messages)
        )
        let modelB = try #require(LLMModelID(providerID: "test-provider", modelID: "model-b"))
        adapter.select(modelID: modelB.rawValue)

        #expect(messages.inserted.isEmpty, "没有会话时不应写入时间线消息")
    }

    @Test("切换未真正生效时不产生时间线消息（不写误导性的已切换）")
    func ineffectiveSwitchProducesNoTimelineMessage() throws {
        let (defaults, suiteName) = Self.makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let previous = LLMManagerUserDefaults.current
        LLMManagerUserDefaults.current = defaults
        defer { LLMManagerUserDefaults.current = previous }

        let llm = DefaultLLMManager()
        try llm.register(TwoModelProvider())
        let modelB = try #require(LLMModelID(providerID: "test-provider", modelID: "model-b"))

        // 会话写入静默失败：会话 ID 存在，但 `selectModel` 什么也不做。
        // 这模拟「会话已被整表重载替换、不在缓存数组里」的真实故障。
        let conversations = SilentConversationManager(conversationID: UUID())
        let messages = RecordingMessageManager()
        let adapter = Self.makeAdapter(
            conversations: conversations,
            llmManager: llm,
            recorder: ModelSwitchTimelineRecorder(messages: messages)
        )
        adapter.select(modelID: modelB.rawValue)

        #expect(
            messages.inserted.isEmpty,
            "切换实际没生效时不应写「已切换」的时间线消息"
        )
    }

    @Test("摘要文案区分「首次选定」与「从 A 切到 B」")
    func summaryTextDistinguishesFirstSelection() {
        let first = ModelSwitchTimeline.summaryText(
            fromProviderID: nil,
            fromModelName: nil,
            toProviderID: "openai",
            toModelName: "gpt-5"
        )
        #expect(first.contains("gpt-5"))
        #expect(!first.contains("已从"), "首次选定不应编造一个旧模型")

        let switched = ModelSwitchTimeline.summaryText(
            fromProviderID: "openai",
            fromModelName: "gpt-5",
            toProviderID: "anthropic",
            toModelName: "claude-opus"
        )
        #expect(switched.contains("gpt-5"))
        #expect(switched.contains("claude-opus"))
    }
}
