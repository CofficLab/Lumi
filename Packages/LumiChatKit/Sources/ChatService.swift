import Foundation
import LumiCoreKit
import LLMKit
import SwiftData

@MainActor
public final class ChatService: ObservableObject, LumiChatServicing {
    public static weak var shared: ChatService?

    // MARK: - Core Reference

    /// LumiCore 引用。声明为 `var` 以支持延迟注入——LumiCore 创建 ChatService 时
    /// 处于两阶段初始化中,无法把 self 传进来,因此 init 先留空,
    /// 由 RootContainer 在 LumiCore 创建完成后调 `configure(lumiCore:)` 回填。
    /// 在 configure 之前,凡是读 lumiCore 的地方都已用 `if let lumiCore` / `?.` 守护。
    public private(set) var lumiCore: (any LumiCoreAccessing)?

    /// 回填 LumiCore 引用。由 RootContainer 在 LumiCore 创建完成后调用一次。
    public func configure(lumiCore: any LumiCoreAccessing) {
        self.lumiCore = lumiCore
    }

    // MARK: - Published State

    @Published public internal(set) var conversations: [LumiConversationSummary]
    @Published public internal(set) var selectedConversationID: UUID?
    @Published public internal(set) var providerInfos: [LumiLLMProviderInfo] = []
    @Published public internal(set) var selectedProviderID: String?
    @Published public internal(set) var selectedModel: String?
    @Published public internal(set) var messageRenderers: [LumiMessageRendererItem] = []
    @Published public internal(set) var revision: Int = 0
    @Published public internal(set) var pendingMessages: [LumiPendingMessage] = []
    @Published public internal(set) var routingMode: LumiModelRoutingMode = .manual
    @Published public internal(set) var pendingToolConfirmation: LumiPendingToolConfirmation?

    // MARK: - Internal State

    var messagesByConversationID: [UUID: [LumiChatMessage]]
    var toolApprovalContinuation: CheckedContinuation<Bool, Never>?
    /// 运行时供应商实例（按 id 索引），供设置页等需要直接操作实例的 UI 层访问。
    /// 写入由 `ProviderManager` 负责，外部只读即可。
    public internal(set) var providersByID: [String: any LumiLLMProvider] = [:]
    var middlewares: [any LumiSendMiddleware] = []
    var turnChecks: [any LumiAgentTurnCheck] = [ToolLoopLimitCheck()]
    weak var toolService: (any LumiToolServicing)?
    let store: ChatStore
    /// `Sendable` container captured at init for background, off-main-actor
    /// history queries (see `fetchDailyMessageCounts(since:)`). Safe to share
    /// across actors; per-call contexts are built on demand from it.
    nonisolated internal let backgroundQueryContainer: ModelContainer
    let statusState = ConversationStatusState()
    var activeTasksByConversationID: [UUID: Task<Void, Never>] = [:]
    var sendingConversationIDs: Set<UUID> = []
    let llmRetryCount = 3
    let defaultPageSize = 10
    let modelRouter = ModelRouter()
    var persistCallCount = 0

    /// 空响应（empty response）最大重试次数。
    /// 不含首次调用，即总共最多调用 LLM `1 + emptyResponseMaxRetries` 次。
    let emptyResponseMaxRetries = 2

    /// 正文内联工具调用（inline tool call）最大重试次数。
    /// 模型把工具调用写进正文而非结构化 `toolCalls` 时，追加纠正消息后重试。
    /// 不含首次调用，即总共最多调用 LLM `1 + inlineToolCallMaxRetries` 次。
    let inlineToolCallMaxRetries = 1

    /// Agent turn 结束后的插件钩子回调
    public var turnFinishedHook: ((UUID, LumiTurnEndReason) async -> Void)?

    /// 工具执行后的插件钩子回调
    ///
    /// 在每次工具执行完成后、决定是否继续 Agent 循环之前调用。
    /// 返回 `true` 表示需要暂停循环等待用户输入（如 ask_user）。
    /// 由 App 层（RootContainer）注入，避免 LumiChatKit 反向依赖插件注册表。
    public var toolExecutionHook: ((String, String, UUID) async -> Bool)?

    /// AskUser 通知观察者
    private var askUserObserver: NSObjectProtocol?

    /// 插件贡献源（由 App 层注入，通常是 `PluginService`）。
    /// 持有它以便 turn 结束时回调、运行期插件状态变化时重新应用贡献。
    private var contributionProvider: (any LumiChatContributionProviding)?

    // MARK: - Delegates

    private(set) var conversationManager: ConversationManager!
    private(set) var providerManager: ProviderManager!
    private(set) var messageManager: MessageManager!
    private(set) var sendPipeline: SendPipeline!

    // MARK: - Init

    public init(configuration: Configuration, lumiCore: (any LumiCoreAccessing)? = nil) {
        let store = ChatStore(configuration: configuration)
        self.store = store
        self.backgroundQueryContainer = store.sharedContainer
        self.lumiCore = lumiCore
        let snapshot = store.load()
        self.conversations = snapshot.conversations
        self.messagesByConversationID = MessageManager.messagesByMergingToolResults(snapshot.messagesByConversationID)
        self.selectedConversationID = snapshot.selectedConversationID
        self.selectedProviderID = snapshot.selectedProviderID
        self.selectedModel = snapshot.selectedModel
        self.routingMode = snapshot.routingMode

        // Initialize delegates (must be after self is partially initialized)
        self.conversationManager = ConversationManager(service: self)
        self.providerManager = ProviderManager(service: self)
        self.messageManager = MessageManager(service: self)
        self.sendPipeline = SendPipeline(service: self)

        Self.shared = self
        
        // 监听 AskUser 回答通知
        setupAskUserNotificationObserver()
    }
    
    /// 设置 AskUser 通知观察者
    private func setupAskUserNotificationObserver() {
        askUserObserver = NotificationCenter.default.addObserver(
            forName: .lumiAskUserDidAnswer,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            
            let userInfo = notification.userInfo ?? [:]
            guard let conversationIdStr = userInfo[LumiAskUserNotification.conversationIDKey] as? String,
                  let conversationID = UUID(uuidString: conversationIdStr),
                  let toolCallID = userInfo[LumiAskUserNotification.toolCallIDKey] as? String,
                  let answer = userInfo[LumiAskUserNotification.answerKey] as? String
            else {
                return
            }
            
            Task { @MainActor in
                await self.resumeAfterAskUser(conversationID: conversationID, toolCallID: toolCallID, answer: answer)
            }
        }
    }

    // MARK: - Registration

    public func registerProviders(_ providers: [any LumiLLMProvider]) {
        providerManager.registerProviders(providers)
    }

    public func registerMiddlewares(_ middlewares: [any LumiSendMiddleware]) {
        self.middlewares = middlewares
    }

    public func registerMessageRenderers(_ renderers: [LumiMessageRendererItem]) {
        let uniqueRenderers = renderers.reduce(into: [String: LumiMessageRendererItem]()) { result, renderer in
            result[renderer.id] = renderer
        }
        self.messageRenderers = uniqueRenderers.values.sorted { lhs, rhs in
            if lhs.order == rhs.order {
                return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
            }
            return lhs.order > rhs.order
        }
    }

    /// Built-in tools that are always available, regardless of loaded plugins.
    public static let builtInTools: [any LumiAgentTool] = [
        NoOpTool(),
        ConversationInfoTool(),
    ]

    public var agentTools: [any LumiAgentTool] {
        // 优先返回 `toolService` 已注册的完整工具列表（包含 plugin 工具 + 已被
        // `registerBuiltInTools` 注入的内置工具）。仅在 `toolService` 尚未就绪时
        // 退回到 `builtInTools`，避免与 `toolService` 重复拼装造成同名工具出现两次。
        toolService?.tools ?? Self.builtInTools
    }

    public func registerToolService(_ toolService: (any LumiToolServicing)?) {
        self.toolService = toolService
    }

    public func registerTurnChecks(_ checks: [any LumiAgentTurnCheck]) {
        self.turnChecks = checks
    }

    /// 应用插件贡献（LLM Provider / 中间件 / 渲染器 / turn 结束钩子）。
    ///
    /// 把原先散落在 App 层 `RootContainer.reloadChatPluginContributions` 的注册逻辑
    /// 收回到 ChatService 内部：ChatService 通过 `LumiChatContributionProviding`
    /// 协议直接向贡献源拉取并注册，不再需要 App 层逐个调用 register*。
    ///
    /// `toolExecutionHook` 仍由 App 层注入——它是 App 层对 `LumiPluginRegistry`
    /// 的反向桥接（决定工具执行后是否暂停 Agent 循环，如 ask_user），不属于"贡献物"，
    /// 因此不进协议，保留为闭包注入。见 `toolExecutionHook` 字段注释。
    public func applyPluginContributions(
        from provider: any LumiChatContributionProviding,
        toolExecutionHook: ((String, String, UUID) async -> Bool)? = nil
    ) {
        self.contributionProvider = provider
        let context = makeChatPluginContext()
        registerProviders(provider.llmProviders(context: context))
        registerMiddlewares(provider.sendMiddlewares(context: context))
        registerMessageRenderers(provider.messageRenderers(context: context))
        turnFinishedHook = { [weak self, weak provider] conversationID, reason in
            // 每次回调重建 context：贡献源可能在运行期变化（插件启用/禁用），
            // 回调发生时拉取最新快照，而不是复用注册时的陈旧 context。
            guard let self, let provider else { return }
            await provider.onTurnFinished(
                context: self.makeChatPluginContext(),
                conversationID: conversationID,
                reason: reason
            )
        }
        self.toolExecutionHook = toolExecutionHook
    }

    /// 构造 Chat 作用域的插件上下文快照。
    private func makeChatPluginContext() -> LumiPluginContext {
        if let lumiCore {
            // 走协议签名需显式传全部参数（协议方法无默认值）。
            return lumiCore.makePluginContext(
                activeSectionID: "chat.core",
                activeSectionTitle: "Chat Core",
                chatSection: .none,
                showsRail: false,
                showsPanelChrome: false,
                isChatSectionVisible: nil,
                additionalDependencies: { _ in }
            )
        }
        // lumiCore 理论上必非空（由 RootContainer 工厂注入），此分支仅作防御兜底。
        return LumiPluginContext(
            activeSectionID: "chat.core",
            activeSectionTitle: "Chat Core"
        )
    }

    // MARK: - Conversation Lifecycle (delegated)

    @discardableResult
    public func createConversation(title: String? = nil) -> UUID {
        conversationManager.createConversation(title: title, projectPath: nil, language: nil)
    }

    @discardableResult
    public func createConversation(
        title: String?,
        projectPath: String?,
        language: LumiConversationLanguage?
    ) -> UUID {
        conversationManager.createConversation(title: title, projectPath: projectPath, language: language)
    }

    public func selectConversation(id: UUID) {
        conversationManager.selectConversation(id: id)
    }

    func conversationSummary(for id: UUID) -> LumiConversationSummary? {
        conversationManager.conversationSummary(for: id)
    }

    public func deleteConversation(id: UUID) {
        conversationManager.deleteConversation(id: id)
    }

    @discardableResult
    public func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool {
        conversationManager.updateConversationTitle(title, for: conversationID)
    }

    @discardableResult
    public func setConversationProjectPath(_ projectPath: String?, for conversationID: UUID) -> Bool {
        conversationManager.setConversationProjectPath(projectPath, for: conversationID)
    }

    // MARK: - Preferences (delegated)

    public func language(for conversationID: UUID?) -> LumiConversationLanguage {
        conversationManager.language(for: conversationID)
    }

    public func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {
        conversationManager.setLanguage(language, for: conversationID)
    }

    public func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel {
        conversationManager.automationLevel(for: conversationID)
    }

    public func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {
        conversationManager.setAutomationLevel(automationLevel, for: conversationID)
    }

    public func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity {
        conversationManager.verbosity(for: conversationID)
    }

    public func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) {
        conversationManager.setVerbosity(verbosity, for: conversationID)
    }

    // MARK: - Provider & Routing (delegated)

    public func selectProvider(id: String, model: String? = nil) {
        providerManager.selectProvider(id: id, model: model)
    }

    public func selectProvider(id: String, model: String?, for conversationID: UUID?) {
        providerManager.selectProvider(id: id, model: model, for: conversationID)
    }

    public func providerID(for conversationID: UUID?) -> String? {
        providerManager.providerID(for: conversationID)
    }

    public func modelName(for conversationID: UUID?) -> String? {
        providerManager.modelName(for: conversationID)
    }

    public func provider(forID id: String) -> (any LumiLLMProvider)? {
        providerManager.provider(byID: id)
    }

    public func setRoutingMode(_ mode: LumiModelRoutingMode) {
        providerManager.setRoutingMode(mode)
    }

    // MARK: - Messages (delegated)

    public func messages(for conversationID: UUID) -> [LumiChatMessage] {
        messageManager.messages(for: conversationID)
    }

    public func displayMessages(for conversationID: UUID) -> [LumiChatMessage] {
        messageManager.displayMessages(for: conversationID)
    }

    public func transientStatusMessage(for conversationID: UUID) -> LumiChatMessage? {
        statusState.statusMessage(for: conversationID)
    }

    public func visibleMessages(for conversationID: UUID, limit: Int, beforeMessageID: UUID?) -> [LumiChatMessage] {
        messageManager.visibleMessages(for: conversationID, limit: limit, beforeMessageID: beforeMessageID)
    }

    public func hasEarlierMessages(for conversationID: UUID, beforeMessageID: UUID?) -> Bool {
        messageManager.hasEarlierMessages(for: conversationID, beforeMessageID: beforeMessageID)
    }

    public func conversationContextUsage(for conversationID: UUID) -> LumiConversationContextUsage {
        LumiConversationContextCalculator.usage(
            messages: messages(for: conversationID),
            providerID: providerID(for: conversationID),
            modelName: modelName(for: conversationID),
            providerInfos: providerInfos
        )
    }

    public func renderer(for message: LumiChatMessage) -> LumiMessageRendererItem? {
        messageRenderers.first { $0.canRender(message) }
    }

    // MARK: - Send Pipeline (delegated)

    public func isSending(for conversationID: UUID?) -> Bool {
        sendPipeline.isSending(for: conversationID)
    }

    public func enqueueText(_ text: String, in conversationID: UUID?) {
        enqueueText(text, imageAttachments: [], in: conversationID)
    }

    public func enqueueText(
        _ text: String,
        imageAttachments: [LumiImageAttachment],
        in conversationID: UUID?
    ) {
        sendPipeline.enqueueText(text, imageAttachments: imageAttachments, in: conversationID)
    }

    public func approvePendingTool() {
        sendPipeline.approvePendingTool()
    }

    public func rejectPendingTool() {
        sendPipeline.rejectPendingTool()
    }

    public func cancelSending(for conversationID: UUID? = nil) {
        sendPipeline.cancelSending(for: conversationID)
    }

    public func removePendingMessage(id: UUID) {
        sendPipeline.removePendingMessage(id: id)
    }

    public func deleteMessage(id: UUID, in conversationID: UUID) {
        messageManager.deleteMessage(id: id, in: conversationID)
    }

    public func resendMessage(id: UUID, in conversationID: UUID) async {
        guard let message = messages(for: conversationID).first(where: { $0.id == id }),
              message.role == .user
        else {
            return
        }
        sendPipeline.enqueueText(message.content, imageAttachments: [], in: conversationID)
    }

    public func send(_ text: String, in conversationID: UUID?) async {
        enqueueText(text, in: conversationID)
        while isSending(for: conversationID ?? selectedConversationID) || pendingMessages.contains(where: {
            $0.conversationID == (conversationID ?? selectedConversationID)
        }) {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    public func generateEphemeralCompletion(
        messages: [LumiChatMessage],
        model: String,
        conversationID: UUID
    ) async throws -> LumiChatMessage {
        guard let providerID = providerID(for: conversationID),
              let provider = providersByID[providerID]
        else {
            throw NSError(
                domain: "LumiChatService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "No LLM provider configured for conversation"]
            )
        }

        return try await provider.send(
            LumiLLMRequest(messages: messages, model: model, tools: [])
        )
    }

    // MARK: - Internal Helpers (delegated to pipeline)

    func prepareSendContext(
        _ messages: [LumiChatMessage],
        conversationID: UUID
    ) async -> LumiSendContext {
        await sendPipeline.prepareSendContext(messages, conversationID: conversationID)
    }

    func requestToolApproval(
        conversationID: UUID,
        toolCall: LumiToolCall,
        displayDescription: String
    ) async -> Bool {
        await sendPipeline.requestToolApproval(
            conversationID: conversationID,
            toolCall: toolCall,
            displayDescription: displayDescription
        )
    }

    func makeAssistantMessage(
        conversationID: UUID,
        messages: [LumiChatMessage],
        imageAttachments: [LumiImageAttachment]
    ) async throws -> LumiChatMessage {
        try await sendPipeline.makeAssistantMessage(
            conversationID: conversationID,
            messages: messages,
            imageAttachments: imageAttachments
        )
    }

    func append(_ message: LumiChatMessage) {
        messageManager.append(message)
    }

    func updateToolCallResult(
        _ result: LumiToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        conversationID: UUID
    ) {
        messageManager.updateToolCallResult(
            result,
            toolCallID: toolCallID,
            assistantMessageID: assistantMessageID,
            conversationID: conversationID
        )
    }

    /// 回填工具调用的用户友好描述，供 UI 在执行前后展示。
    func updateToolCallDisplayName(
        _ displayName: String,
        toolCallID: String,
        assistantMessageID: UUID,
        conversationID: UUID
    ) {
        messageManager.updateToolCallDisplayName(
            displayName,
            toolCallID: toolCallID,
            assistantMessageID: assistantMessageID,
            conversationID: conversationID
        )
    }

    func incrementRevision() {
        revision += 1
    }

    func appendTurnCompletedMarker(conversationID: UUID) {
        sendPipeline.appendTurnCompletedMarker(conversationID: conversationID)
    }

    func messagesWithConversationPreferences(_ context: LumiSendContext) -> [LumiChatMessage] {
        let conversationID = context.conversationID
        let lang = language(for: conversationID)
        let automation = automationLevel(for: conversationID)
        let verbosity = verbosity(for: conversationID)

        var fragments = [
            LumiConversationPromptDefaults.fragment(for: lang),
            LumiConversationPromptDefaults.fragment(for: automation),
            LumiConversationPromptDefaults.fragment(for: verbosity)
        ]
        fragments.append(contentsOf: context.systemPromptFragments)

        let systemMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .system,
            content: fragments.joined(separator: "\n"),
            metadata: [
                "source": "lumi-conversation-preferences",
                "language": lang.rawValue,
                "automationLevel": automation.rawValue,
                "verbosity": verbosity.rawValue
            ]
        )

        return [systemMessage] + context.messages
    }

    // MARK: - Persistence

    func persist() {
        persistCallCount += 1
        revision += 1
        store.save(
            ChatStore.Snapshot(
                conversations: conversations,
                messagesByConversationID: messagesByConversationID,
                selectedConversationID: selectedConversationID,
                selectedProviderID: selectedProviderID,
                selectedModel: selectedModel,
                routingMode: routingMode
            )
        )
    }

    /// 增量持久化单个对话（新建或更新）。不扫描历史消息。
    func persistConversation(_ conversation: LumiConversationSummary) {
        persistCallCount += 1
        revision += 1
        store.upsertConversation(conversation)
    }

    /// 增量持久化单条消息。不扫描历史消息。
    func persistMessage(_ message: LumiChatMessage) {
        persistCallCount += 1
        revision += 1
        store.upsertMessage(message)
    }

    /// 增量持久化对话更新 + 状态。
    /// 用于 updateConversationTitle、setLanguage 等只改一个对话属性的场景。
    func persistConversationAndState(_ conversation: LumiConversationSummary) {
        persistCallCount += 1
        revision += 1
        store.upsertConversation(conversation)
        store.saveStateOnly(
            selectedConversationID: selectedConversationID,
            selectedProviderID: selectedProviderID,
            selectedModel: selectedModel,
            routingMode: routingMode
        )
    }

    /// 增量持久化对话 + 状态，不递增 revision。
    /// 用于调用方已经手动发送 objectWillChange.send() 的场景（如 createConversation），
    /// 避免额外的 revision 触发多一次 UI 重绘。
    func persistConversationAndStateMerged(_ conversation: LumiConversationSummary) {
        persistCallCount += 1
        store.upsertConversation(conversation)
        store.saveStateOnly(
            selectedConversationID: selectedConversationID,
            selectedProviderID: selectedProviderID,
            selectedModel: selectedModel,
            routingMode: routingMode
        )
    }

    /// 只持久化状态（selectedConversationID 等），不扫描对话和消息。
    func persistStateOnly() {
        persistCallCount += 1
        revision += 1
        store.saveStateOnly(
            selectedConversationID: selectedConversationID,
            selectedProviderID: selectedProviderID,
            selectedModel: selectedModel,
            routingMode: routingMode
        )
    }

    /// 增量删除对话及其消息。
    func persistDeleteConversation(id: UUID) {
        persistCallCount += 1
        revision += 1
        store.deleteConversationAndMessages(conversationID: id)
    }

    /// 增量删除单条消息。
    func persistDeleteMessage(id: UUID) {
        persistCallCount += 1
        revision += 1
        store.deleteMessage(id: id)
    }

    // MARK: - String Helpers

    func normalizedTitle(_ title: String?) -> String? {
        guard let title else { return nil }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func title(from text: String) -> String {
        conversationManager.title(from: text)
    }

    // MARK: - Empty Response Handling

    /// 生成空响应重试时注入给 LLM 的 nudge 消息。
    ///
    /// 以 `.system` 角色追加在消息列表末尾，提醒模型上一次回复为空，
    /// 需要回应用户请求或总结已完成的工作。
    static func emptyResponseNudgeMessage(
        conversationID: UUID,
        language: LumiConversationLanguage
    ) -> LumiChatMessage {
        let content: String
        switch language {
        case .chinese:
            content = "注意：你的上一次回复没有可见内容。请回应用户的请求。" +
                "如果你已经完成了任务，请简要总结你的工作成果；" +
                "如果任务尚未完成，请继续执行。"
        case .english:
            content = "Note: Your previous response contained no visible content. " +
                "Please respond to the user's request. " +
                "If you have completed the task, briefly summarize what was accomplished; " +
                "if the task is incomplete, continue working on it."
        }

        return LumiChatMessage(
            conversationID: conversationID,
            role: .system,
            content: content,
            metadata: ["lumi-nudge": "empty-response-retry"]
        )
    }

    /// 重试耗尽后展示给用户的 fallback 提示文案。
    static func emptyResponseFallbackMessage(language: LumiConversationLanguage) -> String {
        switch language {
        case .chinese:
            return "抱歉，模型多次返回了空响应，未能完成你的请求。" +
                "你可以尝试重新表述需求，或重新发送消息重试。"
        case .english:
            return "Sorry, the model returned empty responses after multiple retries " +
                "and could not complete your request. " +
                "Please try rephrasing your request or resend your message."
        }
    }

    // MARK: - Inline Tool Call Handling

    /// 生成正文内联工具调用重试时注入给 LLM 的纠正消息。
    ///
    /// 以 `.system` 角色临时追加在消息列表末尾（不 append、不持久化），
    /// 告诉模型上一次把工具调用写进了正文，应改用结构化 `tool_use` 接口输出。
    static func inlineToolCallNudgeMessage(
        conversationID: UUID,
        language: LumiConversationLanguage
    ) -> LumiChatMessage {
        let content: String
        switch language {
        case .chinese:
            content = "注意：你的上一次回复把工具调用以文本形式写进了正文，" +
                "而非使用结构化的工具调用接口。这是错误的。" +
                "请重新生成回复，通过工具调用接口（tool_use）发起工具调用，" +
                "不要在正文中输出 <tool_call>、<function_calls>、JSON 工具调用块等格式。"
        case .english:
            content = "Note: Your previous response wrote tool calls as text in the body " +
                "instead of using the structured tool-call interface. That is incorrect. " +
                "Please regenerate your response and invoke tools via the tool_use interface; " +
                "do not emit <tool_call>, <function_calls>, JSON tool-call blocks, etc. in the body."
        }

        return LumiChatMessage(
            conversationID: conversationID,
            role: .system,
            content: content,
            metadata: ["lumi-nudge": "inline-tool-call-retry"]
        )
    }

    /// 正文内联工具调用重试耗尽后展示给用户的 fallback 提示文案。
    static func inlineToolCallFallbackMessage(language: LumiConversationLanguage) -> String {
        switch language {
        case .chinese:
            return "抱歉，模型多次将工具调用写入正文而非结构化格式，未能正常执行。" +
                "你可以尝试重新发送消息重试。"
        case .english:
            return "Sorry, the model repeatedly wrote tool calls into the response body " +
                "instead of the structured format, so they could not be executed. " +
                "Please try resending your message."
        }
    }

    /// 调用 LLM 生成 assistant 消息，遇到空响应时自动重试。
    ///
    /// - 首次调用使用原始 `baseMessages`。
    /// - 若返回空响应，注入 nudge 消息后重调，最多重试 `emptyResponseMaxRetries` 次。
    /// - 重试过程中的空消息**不** append、**不**持久化，避免污染对话历史。
    /// - 重试耗尽后返回最后的空消息，由调用方决定 fallback 策略。
    func makeAssistantMessageWithEmptyRetry(
        conversationID: UUID,
        baseMessages: [LumiChatMessage],
        imageAttachments: [LumiImageAttachment]
    ) async throws -> LumiChatMessage {
        let maxRetries = emptyResponseMaxRetries
        let conversationLanguage = language(for: conversationID)
        var lastMessage: LumiChatMessage?

        for attempt in 0 ... maxRetries {
            try Task.checkCancellation()

            let messagesToSend: [LumiChatMessage]
            if attempt == 0 {
                messagesToSend = baseMessages
            } else {
                // 注入 nudge，追加在消息列表末尾
                messagesToSend = baseMessages + [
                    Self.emptyResponseNudgeMessage(
                        conversationID: conversationID,
                        language: conversationLanguage
                    )
                ]
                statusState.setStatus(
                    conversationID: conversationID,
                    content: "模型返回空响应，正在重试（\(attempt)/\(maxRetries)）..."
                )
                incrementRevision()
            }

            let message = try await makeAssistantMessage(
                conversationID: conversationID,
                messages: messagesToSend,
                imageAttachments: imageAttachments
            )
            lastMessage = message

            // 非空响应，直接返回
            if !message.isEmptyResponse {
                return message
            }
        }

        // 重试耗尽，返回最后的空消息（调用方处理 fallback）
        guard let finalMessage = lastMessage else {
            // 理论上不可达（循环至少执行一次），防御性处理
            return LumiChatMessage(
                conversationID: conversationID,
                role: .error,
                content: "Empty response retry produced no message.",
                isError: true
            )
        }
        return finalMessage
    }

    /// 检测到正文内联工具调用时，追加纠正消息后重试。
    ///
    /// 调用方应先通过 `makeAssistantMessageWithEmptyRetry` 拿到首条消息，
    /// 若该消息 `hasInlineToolCallInBody`，再传入本方法从纠正重试开始——
    /// 避免对同一条已判定为内联的消息重复请求。
    ///
    /// - 首次迭代复用传入的 `firstMessage`（不再请求 LLM）。
    /// - 若仍含内联工具调用，注入纠正 nudge 后重调，最多重试 `inlineToolCallMaxRetries` 次。
    /// - 重试过程中的消息**不** append、**不**持久化，避免污染对话历史。
    /// - 重试耗尽后返回最后一条仍含内联工具调用的消息，由调用方决定 fallback 策略。
    func makeAssistantMessageWithInlineToolCallRetry(
        conversationID: UUID,
        baseMessages: [LumiChatMessage],
        firstMessage: LumiChatMessage,
        imageAttachments: [LumiImageAttachment]
    ) async throws -> LumiChatMessage {
        // 首条消息不含内联工具调用 → 无需重试，直接返回。
        guard firstMessage.hasInlineToolCallInBody else {
            return firstMessage
        }

        let maxRetries = inlineToolCallMaxRetries
        let conversationLanguage = language(for: conversationID)
        var lastMessage = firstMessage

        for attempt in 1 ... maxRetries {
            try Task.checkCancellation()

            // 注入纠正 nudge，追加在消息列表末尾
            let messagesToSend = baseMessages + [
                Self.inlineToolCallNudgeMessage(
                    conversationID: conversationID,
                    language: conversationLanguage
                )
            ]
            statusState.setStatus(
                conversationID: conversationID,
                content: "检测到模型将工具调用写入正文，正在重试（\(attempt)/\(maxRetries)）..."
            )
            incrementRevision()

            let message = try await makeAssistantMessage(
                conversationID: conversationID,
                messages: messagesToSend,
                imageAttachments: imageAttachments
            )
            lastMessage = message

            // 不再含内联工具调用，直接返回
            if !message.hasInlineToolCallInBody {
                return message
            }
        }

        // 重试耗尽，返回最后一条仍含内联工具调用的消息（调用方处理 fallback）
        return lastMessage
    }

    // MARK: - Agent Loop Execution

    /// Executes the agent turn loop: send to LLM → evaluate checks → execute tools → repeat.
    func runAgentTurn(
        conversationID: UUID,
        imageAttachments: [LumiImageAttachment] = []
    ) async throws -> LumiAgentTurnOutcome {
        var iteration = 0

        while true {
            try Task.checkCancellation()

            // ── Phase 1: Call LLM (with empty-response retry) ──────
            let requestMessages = messages(for: conversationID)
            let expandedMessages = Self.messagesByExpandingToolResults(requestMessages)
            let preparedContext = await prepareSendContext(expandedMessages, conversationID: conversationID)
            let baseMessages = messagesWithConversationPreferences(preparedContext)

            var assistantMessage = try await makeAssistantMessageWithEmptyRetry(
                conversationID: conversationID,
                baseMessages: baseMessages,
                imageAttachments: imageAttachments
            )

            // 重试耗尽仍为空响应 → 注入用户可见 fallback，turn 以 failed 结束
            if assistantMessage.isEmptyResponse {
                let fallback = LumiChatMessage(
                    conversationID: conversationID,
                    role: .error,
                    content: Self.emptyResponseFallbackMessage(language: language(for: conversationID)),
                    isError: true,
                    metadata: ["lumi-empty-response": "true"]
                )
                append(fallback)
                statusState.clearStatus(conversationID: conversationID)
                incrementRevision()
                return .failed
            }

            // 模型把工具调用写进了正文（而非结构化 toolCalls）→ 追加纠正消息后重试一次。
            // 重试中的 nudge 不 append、不持久化；耗尽则注入用户可见 fallback，turn 以 failed 结束。
            if assistantMessage.hasInlineToolCallInBody {
                assistantMessage = try await makeAssistantMessageWithInlineToolCallRetry(
                    conversationID: conversationID,
                    baseMessages: baseMessages,
                    firstMessage: assistantMessage,
                    imageAttachments: imageAttachments
                )

                if assistantMessage.hasInlineToolCallInBody {
                    let fallback = LumiChatMessage(
                        conversationID: conversationID,
                        role: .error,
                        content: Self.inlineToolCallFallbackMessage(language: language(for: conversationID)),
                        isError: true,
                        metadata: ["lumi-inline-tool-call": "true"]
                    )
                    append(fallback)
                    statusState.clearStatus(conversationID: conversationID)
                    incrementRevision()
                    return .failed
                }
            }

            append(assistantMessage)
            statusState.clearStatus(conversationID: conversationID)
            incrementRevision()

            // ── Phase 2: Evaluate checks ───────────────────────────
            let turnContext = LumiAgentTurnContext(
                conversationID: conversationID,
                iteration: iteration,
                assistantMessage: assistantMessage,
                messages: messages(for: conversationID)
            )

            for check in turnChecks {
                if let reason = await check.evaluate(turnContext) {
                    append(
                        LumiChatMessage(
                            conversationID: conversationID,
                            role: .error,
                            content: reason,
                            isError: true
                        )
                    )
                    return .failed
                }
            }

            if assistantMessage.role == .error || assistantMessage.isError {
                return .failed
            }

            // ── Phase 3: Execute tool calls (if any) ───────────────
            guard automationLevel(for: conversationID).allowsTools,
                  let toolCalls = assistantMessage.toolCalls,
                  !toolCalls.isEmpty,
                  let toolService
            else {
                return .completed
            }

            for toolCall in toolCalls {
                try Task.checkCancellation()

                // 回填用户友好的操作描述（由工具根据参数生成，如「读取 Foo.swift」），
                // 使界面在执行前后的所有状态下都显示语义化文案，而非原始工具名。
                // 在审批/执行之前完成，因此「加载中」与「已完成」都能受益。
                if let tool = toolService.tool(named: toolCall.name),
                   let arguments = try? Self.decodeToolArguments(toolCall.arguments) {
                    updateToolCallDisplayName(
                        tool.displayDescription(arguments: arguments),
                        toolCallID: toolCall.id,
                        assistantMessageID: assistantMessage.id,
                        conversationID: conversationID
                    )
                }

                if automationLevel(for: conversationID) == .build,
                   let tool = toolService.tool(named: toolCall.name) {
                    // 半截 JSON（流被截断等）时 decode 会抛错；用空字典兜底，
                    // 让工具的 riskLevel 仍能对「无参数」状态做决策——
                    // 不能因为参数解析失败就跳过审批门（否则高危工具会被静默执行）。
                    let arguments = (try? Self.decodeToolArguments(toolCall.arguments)) ?? [:]
                    if tool.riskLevel(
                        arguments: arguments,
                        context: nil
                    ).requiresPermission,
                       !(await requestToolApproval(
                           conversationID: conversationID,
                           toolCall: toolCall,
                           displayDescription: tool.displayDescription(
                               arguments: arguments
                           )
                       )) {
                        updateToolCallResult(
                            LumiToolResult(content: "Tool execution was rejected by the user.", isError: true),
                            toolCallID: toolCall.id,
                            assistantMessageID: assistantMessage.id,
                            conversationID: conversationID
                        )
                        continue
                    }
                }

                let start = Date()
                statusState.setToolProgress(
                    conversationID: conversationID,
                    toolName: toolCall.name,
                    elapsedSeconds: 0,
                    outputPreview: nil
                )
                incrementRevision()

                let progressTask = Task { @MainActor [weak self] in
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        guard let self, !Task.isCancelled else { return }
                        let elapsed = Int(Date().timeIntervalSince(start))
                        self.statusState.setToolProgress(
                            conversationID: conversationID,
                            toolName: toolCall.name,
                            elapsedSeconds: elapsed,
                            outputPreview: nil
                        )
                        self.incrementRevision()
                    }
                }
                defer { progressTask.cancel() }

                let result = await toolService.execute(toolCall, conversationID: conversationID)
                let elapsed = Int(Date().timeIntervalSince(start))
                statusState.setToolCompleted(
                    conversationID: conversationID,
                    toolName: toolCall.name,
                    elapsedSeconds: elapsed
                )
                incrementRevision()

                updateToolCallResult(
                    result,
                    toolCallID: toolCall.id,
                    assistantMessageID: assistantMessage.id,
                    conversationID: conversationID
                )

                // 调用插件工具执行钩子，让插件决定是否需要暂停（如 ask_user 等待用户回答）。
                // 钩子由 App 层注入，避免 LumiChatKit 反向依赖插件注册表。
                if let toolExecutionHook,
                   await toolExecutionHook(toolCall.name, result.content, conversationID) {
                    statusState.setStatus(conversationID: conversationID, content: "等待您的选择…")
                    incrementRevision()
                    return .awaitingUserResponse
                }
            }

            iteration += 1
        }
    }

    public func resumeAfterAskUser(conversationID: UUID, toolCallID: String, answer: String) async {
        guard let (assistantMessageID, toolCall) = Self.assistantMessage(
            containingToolCallID: toolCallID,
            in: messages(for: conversationID)
        ),
        let result = toolCall.result
        else {
            return
        }

        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAnswer.isEmpty else { return }

        updateToolCallResult(
            LumiToolResult(content: trimmedAnswer, duration: result.duration),
            toolCallID: toolCallID,
            assistantMessageID: assistantMessageID,
            conversationID: conversationID
        )
        incrementRevision()

        let task = Task<Void, Never> { @MainActor [weak self] in
            guard let self else { return }
            await self.sendPipeline.continueAgentTurn(conversationID: conversationID)
        }
        activeTasksByConversationID[conversationID] = task
    }

    /// 在不写入任何用户消息的前提下，为该会话重启一轮 agent turn。
    ///
    /// 供插件（如 AutoTask 自动续聊）在「任务尚未完成但上一轮已结束」时
    /// 无感地继续推进——既不向消息列表写入提示词，也不污染持久化历史。
    public func continueTurn(in conversationID: UUID) {
        guard activeTasksByConversationID[conversationID] == nil else { return }
        let task = Task<Void, Never> { @MainActor [weak self] in
            guard let self else { return }
            await self.sendPipeline.continueAgentTurn(conversationID: conversationID)
        }
        activeTasksByConversationID[conversationID] = task
    }

    static func assistantMessage(
        containingToolCallID toolCallID: String,
        in messages: [LumiChatMessage]
    ) -> (assistantMessageID: UUID, toolCall: LumiToolCall)? {
        for message in messages.reversed() {
            guard message.role == .assistant,
                  let toolCalls = message.toolCalls,
                  let toolCall = toolCalls.first(where: { $0.id == toolCallID })
            else {
                continue
            }
            return (message.id, toolCall)
        }
        return nil
    }

    /// Expands tool results from assistant messages into separate tool-role messages.
    static func messagesByExpandingToolResults(_ messages: [LumiChatMessage]) -> [LumiChatMessage] {
        var expanded: [LumiChatMessage] = []

        for message in messages {
            guard message.role != .tool else {
                continue
            }

            expanded.append(message)

            guard message.role == .assistant,
                  let toolCalls = message.toolCalls
            else {
                continue
            }

            for toolCall in toolCalls {
                guard let result = toolCall.result else {
                    continue
                }

                // 跳过尚未回答的 `ask_user` pending 占位内容：它不是真实的工具产出，
                // 不应作为 tool 消息进入下游 LLM 上下文（等用户回答后由
                // `resumeAfterAskUser` 写入真实答案再展开）。
                if LumiAskUserMarkers.isPendingResponse(result.content) {
                    continue
                }

                var metadata: [String: String] = [:]
                // 将工具产出的图片注入 tool 消息，复用与用户附图相同的视觉通道。
                // 下游 LumiVisionMessageSupport.convert 会从该 metadata 还原 MessageImage，
                // provider adapter 的 tool_result-with-images 分支据此序列化为 image 块。
                if !result.imageAttachments.isEmpty {
                    metadata["hasImages"] = "true"
                    if let encoded = MessageManager.encodeImageAttachments(result.imageAttachments) {
                        metadata["imageAttachments"] = encoded
                    }
                }

                expanded.append(
                    LumiChatMessage(
                        conversationID: message.conversationID,
                        role: .tool,
                        content: result.content,
                        isError: result.isError,
                        metadata: metadata,
                        toolCallID: toolCall.id
                    )
                )
            }
        }

        return expanded
    }

    /// Decodes JSON string into a dictionary of `LumiJSONValue`.
    static func decodeToolArguments(_ json: String) throws -> [String: LumiJSONValue] {
        guard let data = json.data(using: .utf8), !data.isEmpty else {
            return [:]
        }
        return try JSONDecoder().decode([String: LumiJSONValue].self, from: data)
    }
}
