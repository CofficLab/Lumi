import Foundation
import LumiCoreKit
import ModelRouterKit

@MainActor
public final class ChatService: ObservableObject, LumiChatServicing, LumiAskUserResuming {
    public static weak var shared: ChatService?

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
    var providersByID: [String: any LumiLLMProvider] = [:]
    var middlewares: [any LumiSendMiddleware] = []
    var turnChecks: [any LumiAgentTurnCheck] = [ToolLoopLimitCheck()]
    weak var toolService: (any LumiToolServicing)?
    var projectPathProvider: (any LumiCurrentProjectPathProviding)?
    let store: ChatStore
    let statusState = ConversationStatusState()
    var activeTasksByConversationID: [UUID: Task<Void, Never>] = [:]
    var sendingConversationIDs: Set<UUID> = []
    let llmRetryCount = 3
    let defaultPageSize = 10
    let modelRouter = ModelRouter()
    var persistCallCount = 0

    // MARK: - Delegates

    private(set) var conversationManager: ConversationManager!
    private(set) var providerManager: ProviderManager!
    private(set) var messageManager: MessageManager!
    private(set) var sendPipeline: SendPipeline!

    // MARK: - Init

    public init(configuration: Configuration) {
        self.store = ChatStore(configuration: configuration)
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
        Self.builtInTools + (toolService?.tools ?? [])
    }

    public func registerToolService(_ toolService: (any LumiToolServicing)?) {
        self.toolService = toolService
    }

    public func registerTurnChecks(_ checks: [any LumiAgentTurnCheck]) {
        self.turnChecks = checks
    }

    public func registerProjectPathProvider(_ provider: any LumiCurrentProjectPathProviding) {
        self.projectPathProvider = provider
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
            lang.systemPromptFragment,
            automation.systemPromptFragment,
            verbosity.systemPromptFragment
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

    // MARK: - Agent Loop Execution

    /// Executes the agent turn loop: send to LLM → evaluate checks → execute tools → repeat.
    func runAgentTurn(
        conversationID: UUID,
        imageAttachments: [LumiImageAttachment] = []
    ) async throws -> LumiAgentTurnOutcome {
        var iteration = 0

        while true {
            try Task.checkCancellation()

            // ── Phase 1: Call LLM ──────────────────────────────────
            let requestMessages = messages(for: conversationID)
            let expandedMessages = Self.messagesByExpandingToolResults(requestMessages)
            let preparedContext = await prepareSendContext(expandedMessages, conversationID: conversationID)
            let assistantMessage = try await makeAssistantMessage(
                conversationID: conversationID,
                messages: messagesWithConversationPreferences(preparedContext),
                imageAttachments: imageAttachments
            )
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
                   let tool = toolService.tool(named: toolCall.name),
                   let arguments = try? Self.decodeToolArguments(toolCall.arguments),
                   tool.riskLevel(
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

                if LumiAskUserMarkers.isPendingResponse(result.content) {
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
        let result = toolCall.result,
        LumiAskUserMarkers.isPendingResponse(result.content)
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
                guard let result = toolCall.result,
                      !LumiAskUserMarkers.isPendingResponse(result.content)
                else {
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
