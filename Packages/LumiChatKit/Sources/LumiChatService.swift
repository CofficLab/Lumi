import Foundation
import LumiCoreKit
import ModelRouterKit

@MainActor
public final class LumiChatService: ObservableObject, LumiChatServicing {
    @Published public private(set) var conversations: [LumiConversationSummary]
    @Published public private(set) var selectedConversationID: UUID?
    @Published public private(set) var providerInfos: [LumiLLMProviderInfo] = []
    @Published public private(set) var selectedProviderID: String?
    @Published public private(set) var selectedModel: String?
    @Published public private(set) var messageRenderers: [LumiMessageRendererItem] = []
    @Published public private(set) var revision: Int = 0
    @Published public private(set) var pendingMessages: [LumiPendingMessage] = []
    @Published public private(set) var routingMode: LumiModelRoutingMode = .manual
    @Published public private(set) var pendingToolConfirmation: LumiPendingToolConfirmation?

    private var messagesByConversationID: [UUID: [LumiChatMessage]]
    private var toolApprovalContinuation: CheckedContinuation<Bool, Never>?
    private var providersByID: [String: any LumiLLMProvider] = [:]
    private var middlewares: [any LumiSendMiddleware] = []
    private weak var toolService: (any LumiToolServicing)?
    private let store: LumiChatStore
    private let statusState = LumiConversationStatusState()
    private var activeTasksByConversationID: [UUID: Task<Void, Never>] = [:]
    private var sendingConversationIDs: Set<UUID> = []
    private let maxToolIterations = 12
    private let llmRetryCount = 3
    private let defaultPageSize = 10
    private let modelRouter = ModelRouter()

    public init(configuration: LumiChatConfiguration) {
        self.store = LumiChatStore(configuration: configuration)
        let snapshot = store.load()
        self.conversations = snapshot.conversations
        self.messagesByConversationID = Self.messagesByMergingToolResults(snapshot.messagesByConversationID)
        self.selectedConversationID = snapshot.selectedConversationID
        self.selectedProviderID = snapshot.selectedProviderID
        self.selectedModel = snapshot.selectedModel
        self.routingMode = snapshot.routingMode
    }

    public func registerProviders(_ providers: [any LumiLLMProvider]) {
        let uniqueProviders = providers.reduce(into: [String: any LumiLLMProvider]()) { result, provider in
            result[type(of: provider).info.id] = provider
        }
        self.providersByID = uniqueProviders
        self.providerInfos = uniqueProviders.values
            .map { type(of: $0).info }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }

        reconcileSelectedProvider()
        persist()
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

    public var agentTools: [any LumiAgentTool] {
        toolService?.tools ?? []
    }

    public func registerToolService(_ toolService: (any LumiToolServicing)?) {
        self.toolService = toolService
    }

    public func isSending(for conversationID: UUID?) -> Bool {
        guard let conversationID = conversationID ?? selectedConversationID else {
            return false
        }
        return sendingConversationIDs.contains(conversationID)
    }

    @discardableResult
    public func createConversation(title: String? = nil) -> UUID {
        let now = Date()
        let conversation = LumiConversationSummary(
            title: normalizedTitle(title) ?? "New Chat",
            createdAt: now,
            updatedAt: now
        )
        conversations.insert(conversation, at: 0)
        messagesByConversationID[conversation.id] = []
        selectedConversationID = conversation.id
        persist()
        return conversation.id
    }

    public func selectConversation(id: UUID) {
        guard conversations.contains(where: { $0.id == id }) else {
            return
        }

        selectedConversationID = id
        persist()
    }

    public func deleteConversation(id: UUID) {
        cancelSending(for: id)
        pendingMessages.removeAll { $0.conversationID == id }
        conversations.removeAll { $0.id == id }
        messagesByConversationID[id] = nil
        statusState.clearStatus(conversationID: id)

        if selectedConversationID == id {
            selectedConversationID = conversations.first?.id
        }

        persist()
    }

    public func selectProvider(id: String, model: String? = nil) {
        selectProvider(id: id, model: model, for: selectedConversationID)
    }

    public func selectProvider(id: String, model: String?, for conversationID: UUID?) {
        guard let info = providerInfos.first(where: { $0.id == id }) else {
            return
        }

        let normalized = normalizedModel(model, for: info)
        selectedProviderID = info.id
        selectedModel = normalized

        if let conversationID,
           let index = conversations.firstIndex(where: { $0.id == conversationID }) {
            conversations[index].providerID = info.id
            conversations[index].modelName = normalized
            conversations[index].updatedAt = Date()
        }

        persist()
    }

    public func providerID(for conversationID: UUID?) -> String? {
        guard let conversationID,
              let conversation = conversations.first(where: { $0.id == conversationID }),
              let providerID = conversation.providerID
        else {
            return selectedProviderID
        }
        return providerID
    }

    public func modelName(for conversationID: UUID?) -> String? {
        guard let conversationID,
              let conversation = conversations.first(where: { $0.id == conversationID }),
              let modelName = conversation.modelName
        else {
            return selectedModel
        }
        return modelName
    }

    public func setRoutingMode(_ mode: LumiModelRoutingMode) {
        routingMode = mode
        persist()
    }

    public func language(for conversationID: UUID?) -> LumiConversationLanguage {
        guard let conversationID,
              let conversation = conversations.first(where: { $0.id == conversationID })
        else {
            return .chinese
        }
        return conversation.language ?? .chinese
    }

    public func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {
        let targetID = conversationID ?? selectedConversationID ?? createConversation(title: nil)
        guard let index = conversations.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        conversations[index].language = language
        conversations[index].updatedAt = Date()
        persist()
    }

    public func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel {
        guard let conversationID,
              let conversation = conversations.first(where: { $0.id == conversationID })
        else {
            return .autonomous
        }
        return conversation.automationLevel ?? .autonomous
    }

    public func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {
        let targetID = conversationID ?? selectedConversationID ?? createConversation(title: nil)
        guard let index = conversations.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        conversations[index].automationLevel = automationLevel
        conversations[index].updatedAt = Date()
        persist()
    }

    public func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity {
        guard let conversationID,
              let conversation = conversations.first(where: { $0.id == conversationID })
        else {
            return .detailed
        }
        return conversation.verbosity ?? .detailed
    }

    public func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) {
        let targetID = conversationID ?? selectedConversationID ?? createConversation(title: nil)
        guard let index = conversations.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        conversations[index].verbosity = verbosity
        conversations[index].updatedAt = Date()
        persist()
    }

    public func messages(for conversationID: UUID) -> [LumiChatMessage] {
        messagesByConversationID[conversationID] ?? []
    }

    public func displayMessages(for conversationID: UUID) -> [LumiChatMessage] {
        var result = messages(for: conversationID).filter {
            $0.role != .status || $0.renderKind == "turn-completed"
        }
        if let status = transientStatusMessage(for: conversationID) {
            result.append(status)
        }
        return result
    }

    public func transientStatusMessage(for conversationID: UUID) -> LumiChatMessage? {
        statusState.statusMessage(for: conversationID)
    }

    public func visibleMessages(for conversationID: UUID, limit: Int, beforeMessageID: UUID?) -> [LumiChatMessage] {
        let allMessages = messages(for: conversationID).filter { $0.role != .status && $0.role != .tool }
        guard !allMessages.isEmpty else {
            return []
        }

        let endIndex: Int
        if let beforeMessageID,
           let index = allMessages.firstIndex(where: { $0.id == beforeMessageID }) {
            endIndex = index
        } else {
            endIndex = allMessages.count
        }

        let startIndex = max(0, endIndex - limit)
        return Array(allMessages[startIndex..<endIndex])
    }

    public func hasEarlierMessages(for conversationID: UUID, beforeMessageID: UUID?) -> Bool {
        let allMessages = messages(for: conversationID).filter { $0.role != .status && $0.role != .tool }
        guard let beforeMessageID,
              let index = allMessages.firstIndex(where: { $0.id == beforeMessageID })
        else {
            return allMessages.count > defaultPageSize
        }
        return index > 0
    }

    public func renderer(for message: LumiChatMessage) -> LumiMessageRendererItem? {
        messageRenderers.first { $0.canRender(message) }
    }

    public func enqueueText(_ text: String, in conversationID: UUID?) {
        enqueueText(text, imageAttachments: [], in: conversationID)
    }

    public func enqueueText(
        _ text: String,
        imageAttachments: [LumiImageAttachment],
        in conversationID: UUID?
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !imageAttachments.isEmpty else {
            return
        }

        let targetID = conversationID ?? selectedConversationID ?? createConversation(title: title(from: trimmed))
        if selectedConversationID != targetID {
            selectConversation(id: targetID)
        }

        pendingMessages.append(
            LumiPendingMessage(
                conversationID: targetID,
                content: trimmed,
                imageAttachments: imageAttachments
            )
        )
        attemptBeginNextSend()
    }

    public func approvePendingTool() {
        pendingToolConfirmation = nil
        toolApprovalContinuation?.resume(returning: true)
        toolApprovalContinuation = nil
    }

    public func rejectPendingTool() {
        pendingToolConfirmation = nil
        toolApprovalContinuation?.resume(returning: false)
        toolApprovalContinuation = nil
    }

    public func cancelSending(for conversationID: UUID? = nil) {
        let targetID = conversationID ?? selectedConversationID
        guard let targetID else {
            return
        }

        activeTasksByConversationID[targetID]?.cancel()
        activeTasksByConversationID[targetID] = nil
        sendingConversationIDs.remove(targetID)
        statusState.setStatus(conversationID: targetID, content: "已停止生成")
        statusState.clearStatus(conversationID: targetID)
        revision += 1
        attemptBeginNextSend()
    }

    public func removePendingMessage(id: UUID) {
        pendingMessages.removeAll { $0.id == id }
        revision += 1
    }

    public func deleteMessage(id: UUID, in conversationID: UUID) {
        guard var messages = messagesByConversationID[conversationID] else {
            return
        }
        messages.removeAll { $0.id == id }
        messagesByConversationID[conversationID] = messages
        persist()
    }

    public func resendMessage(id: UUID, in conversationID: UUID) async {
        guard let message = messages(for: conversationID).first(where: { $0.id == id }),
              message.role == .user
        else {
            return
        }
        enqueueText(message.content, in: conversationID)
    }

    public func send(_ text: String, in conversationID: UUID?) async {
        enqueueText(text, in: conversationID)
        while isSending(for: conversationID ?? selectedConversationID) || pendingMessages.contains(where: {
            $0.conversationID == (conversationID ?? selectedConversationID)
        }) {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private func attemptBeginNextSend() {
        guard let nextIndex = pendingMessages.firstIndex(where: { pending in
            activeTasksByConversationID[pending.conversationID] == nil
        }) else {
            return
        }

        let pending = pendingMessages.remove(at: nextIndex)
        revision += 1

        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            await self.processPendingSend(pending)
        }
        activeTasksByConversationID[pending.conversationID] = task
    }

    private func processPendingSend(_ pending: LumiPendingMessage) async {
        let conversationID = pending.conversationID
        sendingConversationIDs.insert(conversationID)
        revision += 1

        defer {
            activeTasksByConversationID[conversationID] = nil
            sendingConversationIDs.remove(conversationID)
            statusState.clearStatus(conversationID: conversationID)
            revision += 1
            attemptBeginNextSend()
        }

        var userMetadata: [String: String] = [:]
        if !pending.imageAttachments.isEmpty {
            userMetadata["hasImages"] = "true"
            if let encoded = Self.encodeImageAttachments(pending.imageAttachments) {
                userMetadata["imageAttachments"] = encoded
            }
        }

        append(
            LumiChatMessage(
                conversationID: conversationID,
                role: .user,
                content: pending.content,
                metadata: userMetadata
            )
        )
        statusState.setStatus(conversationID: conversationID, content: "正在发送消息…")
        revision += 1

        do {
            try await runAgentTurn(
                conversationID: conversationID,
                imageAttachments: pending.imageAttachments
            )
            appendTurnCompletedMarker(conversationID: conversationID)
        } catch is CancellationError {
            return
        } catch {
            append(
                LumiChatMessage(
                    conversationID: conversationID,
                    role: .error,
                    content: error.localizedDescription,
                    isError: true
                )
            )
        }
    }

    private func runAgentTurn(
        conversationID: UUID,
        imageAttachments: [LumiImageAttachment] = []
    ) async throws {
        for _ in 0..<maxToolIterations {
            try Task.checkCancellation()

            let requestMessages = messages(for: conversationID)
            let expandedMessages = messagesByExpandingToolResults(requestMessages)
            let preparedContext = await prepareSendContext(expandedMessages, conversationID: conversationID)
            let assistantMessage = try await makeAssistantMessage(
                conversationID: conversationID,
                messages: messagesWithConversationPreferences(preparedContext),
                imageAttachments: imageAttachments
            )
            append(assistantMessage)
            statusState.clearStatus(conversationID: conversationID)
            revision += 1

            guard automationLevel(for: conversationID).allowsTools,
                  let toolCalls = assistantMessage.toolCalls,
                  !toolCalls.isEmpty,
                  let toolService
            else {
                return
            }

            for toolCall in toolCalls {
                try Task.checkCancellation()

                if automationLevel(for: conversationID) == .build,
                   let tool = toolService.tool(named: toolCall.name),
                   tool.riskLevel(
                       arguments: (try? Self.decodeToolArguments(toolCall.arguments)) ?? [:],
                       context: nil
                   ).requiresPermission,
                   !(await requestToolApproval(
                       conversationID: conversationID,
                       toolCall: toolCall,
                       displayDescription: tool.displayDescription(
                           arguments: (try? Self.decodeToolArguments(toolCall.arguments)) ?? [:]
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
                revision += 1

                let result = await toolService.execute(toolCall, conversationID: conversationID)
                let elapsed = Int(Date().timeIntervalSince(start))
                statusState.setToolCompleted(
                    conversationID: conversationID,
                    toolName: toolCall.name,
                    elapsedSeconds: elapsed
                )
                revision += 1

                updateToolCallResult(
                    result,
                    toolCallID: toolCall.id,
                    assistantMessageID: assistantMessage.id,
                    conversationID: conversationID
                )
            }
        }

        append(
            LumiChatMessage(
                conversationID: conversationID,
                role: .error,
                content: "Tool call limit reached. The assistant stopped to avoid an infinite tool loop.",
                isError: true
            )
        )
    }

    private func prepareSendContext(
        _ messages: [LumiChatMessage],
        conversationID: UUID
    ) async -> LumiSendContext {
        var context = LumiSendContext(conversationID: conversationID, messages: messages)
        for middleware in middlewares {
            do {
                context = try await middleware.prepare(context)
            } catch {
                break
            }
        }
        return context
    }

    private func requestToolApproval(
        conversationID: UUID,
        toolCall: LumiToolCall,
        displayDescription: String
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            toolApprovalContinuation = continuation
            pendingToolConfirmation = LumiPendingToolConfirmation(
                conversationID: conversationID,
                toolCall: toolCall,
                displayDescription: displayDescription
            )
            revision += 1
        }
    }

    private func appendTurnCompletedMarker(conversationID: UUID) {
        append(
            LumiChatMessage(
                conversationID: conversationID,
                role: .status,
                content: LumiChatMarkers.turnCompleted,
                renderKind: "turn-completed"
            )
        )
    }

    private func makeAssistantMessage(
        conversationID: UUID,
        messages: [LumiChatMessage],
        imageAttachments: [LumiImageAttachment] = []
    ) async throws -> LumiChatMessage {
        guard let provider = resolvedProvider(for: conversationID) else {
            return LumiChatMessage(
                conversationID: conversationID,
                role: .assistant,
                content: "Chat core is ready. LLM providers will be connected by plugins."
            )
        }

        let providerInfo = type(of: provider).info
        let model = resolvedModel(for: conversationID, providerInfo: providerInfo)
        let tools = automationLevel(for: conversationID).allowsTools ? agentTools : []
        let request = LumiLLMRequest(
            messages: messagesWithImageContext(messages, imageAttachments: imageAttachments),
            model: model,
            tools: tools,
            imageAttachments: imageAttachments
        )

        var lastError: Error?
        for attempt in 0..<llmRetryCount {
            try Task.checkCancellation()
            if attempt > 0 {
                statusState.setStatus(
                    conversationID: conversationID,
                    content: "重试中（\(attempt + 1)/\(llmRetryCount)）..."
                )
                revision += 1
                let delay = UInt64(pow(2.0, Double(attempt))) * 500_000_000
                try await Task.sleep(nanoseconds: delay)
            }

            do {
                return try await provider.sendStreaming(request) { [weak self] chunk in
                    await MainActor.run {
                        guard let self else { return }
                        self.statusState.applyStreamChunk(conversationID: conversationID, chunk: chunk)
                        self.revision += 1
                    }
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }

        return LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: lastError?.localizedDescription ?? "Request failed.",
            providerID: providerInfo.id,
            modelName: model,
            isError: true,
            rawErrorDetail: lastError?.localizedDescription
        )
    }

    private func resolvedProvider(for conversationID: UUID) -> (any LumiLLMProvider)? {
        if routingMode == .auto {
            return autoRoutedProvider(for: conversationID)
        }

        if let providerID = providerID(for: conversationID),
           let provider = providersByID[providerID] {
            return provider
        }
        return selectedProvider
    }

    private func autoRoutedProvider(for conversationID: UUID) -> (any LumiLLMProvider)? {
        guard !providersByID.isEmpty else {
            return nil
        }

        guard let decision = modelRouter.route(
            candidates: routeCandidates(),
            signal: routeSignal(for: conversationID)
        ),
        let provider = providersByID[decision.providerId]
        else {
            return providersByID[providerID(for: conversationID) ?? ""] ?? providersByID.values.first
        }

        return provider
    }

    private func resolvedModel(for conversationID: UUID, providerInfo: LumiLLMProviderInfo) -> String {
        if routingMode == .auto,
           let decision = modelRouter.route(
               candidates: routeCandidates(),
               signal: routeSignal(for: conversationID)
           ),
           decision.providerId == providerInfo.id {
            return normalizedModel(decision.model, for: providerInfo)
        }

        return normalizedModel(modelName(for: conversationID), for: providerInfo)
    }

    private func routeCandidates() -> [RouteCandidate] {
        providerInfos.flatMap { info in
            info.availableModels.map { model in
                RouteCandidate(
                    providerId: info.id,
                    providerDisplayName: info.displayName,
                    model: model,
                    availability: .available
                )
            }
        }
    }

    private func routeSignal(for conversationID: UUID) -> RouteSignal {
        let latestUserMessage = messages(for: conversationID).last(where: { $0.role == .user })
        return RouteSignal(
            hasImages: latestUserMessage?.metadata["hasImages"] == "true",
            messageLength: latestUserMessage?.content.count ?? 0,
            allowsTools: automationLevel(for: conversationID).allowsTools,
            currentProviderId: providerID(for: conversationID) ?? selectedProviderID ?? "",
            currentModel: modelName(for: conversationID) ?? selectedModel ?? ""
        )
    }

    private var selectedProvider: (any LumiLLMProvider)? {
        guard let selectedProviderID else {
            return nil
        }
        return providersByID[selectedProviderID]
    }

    private func messagesWithConversationPreferences(_ context: LumiSendContext) -> [LumiChatMessage] {
        let conversationID = context.conversationID
        let language = language(for: conversationID)
        let automationLevel = automationLevel(for: conversationID)
        let verbosity = verbosity(for: conversationID)

        var fragments = [
            language.systemPromptFragment,
            automationLevel.systemPromptFragment,
            verbosity.systemPromptFragment
        ]
        fragments.append(contentsOf: context.systemPromptFragments)

        let systemMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .system,
            content: fragments.joined(separator: "\n"),
            metadata: [
                "source": "lumi-conversation-preferences",
                "language": language.rawValue,
                "automationLevel": automationLevel.rawValue,
                "verbosity": verbosity.rawValue
            ]
        )

        return [systemMessage] + context.messages
    }

    private func reconcileSelectedProvider() {
        guard !providerInfos.isEmpty else {
            selectedProviderID = nil
            selectedModel = nil
            return
        }

        if let selectedProviderID,
           let info = providerInfos.first(where: { $0.id == selectedProviderID }) {
            selectedModel = normalizedModel(selectedModel, for: info)
            return
        }

        let info = providerInfos[0]
        selectedProviderID = info.id
        selectedModel = info.defaultModel
    }

    private func normalizedModel(_ model: String?, for info: LumiLLMProviderInfo) -> String {
        guard let model,
              info.availableModels.contains(model)
        else {
            return info.defaultModel
        }
        return model
    }

    private func append(_ message: LumiChatMessage) {
        if message.role == .status, message.renderKind != "turn-completed" {
            return
        }
        messagesByConversationID[message.conversationID, default: []].append(message)
        updateConversationSummary(for: message)
        persist()
    }

    private func updateToolCallResult(
        _ result: LumiToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        conversationID: UUID
    ) {
        guard var messages = messagesByConversationID[conversationID],
              let messageIndex = messages.firstIndex(where: { $0.id == assistantMessageID }),
              var toolCalls = messages[messageIndex].toolCalls,
              let toolCallIndex = toolCalls.firstIndex(where: { $0.id == toolCallID })
        else {
            return
        }

        toolCalls[toolCallIndex].result = result
        messages[messageIndex].toolCalls = toolCalls
        messagesByConversationID[conversationID] = messages
        persist()
    }

    private func updateConversationSummary(for message: LumiChatMessage) {
        guard let index = conversations.firstIndex(where: { $0.id == message.conversationID }) else {
            return
        }

        var conversation = conversations[index]
        conversation.preview = message.content
        conversation.updatedAt = message.createdAt

        if conversation.title == "New Chat", message.role == .user {
            conversation.title = title(from: message.content)
        }

        conversations.remove(at: index)
        conversations.insert(conversation, at: 0)
    }

    private func persist() {
        revision += 1
        store.save(
            LumiChatStore.Snapshot(
                conversations: conversations,
                messagesByConversationID: messagesByConversationID,
                selectedConversationID: selectedConversationID,
                selectedProviderID: selectedProviderID,
                selectedModel: selectedModel,
                routingMode: routingMode
            )
        )
    }

    private func normalizedTitle(_ title: String?) -> String? {
        guard let title else {
            return nil
        }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func title(from text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 28 {
            return trimmed.isEmpty ? "New Chat" : trimmed
        }
        return "\(trimmed.prefix(28))..."
    }

    private func messagesByExpandingToolResults(_ messages: [LumiChatMessage]) -> [LumiChatMessage] {
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

                expanded.append(
                    LumiChatMessage(
                        conversationID: message.conversationID,
                        role: .tool,
                        content: result.content,
                        isError: result.isError,
                        toolCallID: toolCall.id
                    )
                )
            }
        }

        return expanded
    }

    private static func messagesByMergingToolResults(
        _ messagesByConversationID: [UUID: [LumiChatMessage]]
    ) -> [UUID: [LumiChatMessage]] {
        messagesByConversationID.mapValues { messages in
            var merged = messages
            var assistantIndexByToolCallID: [String: Int] = [:]

            for index in merged.indices {
                guard merged[index].role == .assistant,
                      let toolCalls = merged[index].toolCalls
                else {
                    continue
                }

                for toolCall in toolCalls {
                    assistantIndexByToolCallID[toolCall.id] = index
                }
            }

            for message in messages where message.role == .tool {
                guard let toolCallID = message.toolCallID,
                      let assistantIndex = assistantIndexByToolCallID[toolCallID],
                      var toolCalls = merged[assistantIndex].toolCalls,
                      let toolCallIndex = toolCalls.firstIndex(where: { $0.id == toolCallID }),
                      toolCalls[toolCallIndex].result == nil
                else {
                    continue
                }

                toolCalls[toolCallIndex].result = LumiToolResult(
                    content: message.content,
                    isError: message.isError
                )
                merged[assistantIndex].toolCalls = toolCalls
            }

            return merged
        }
    }

    private func messagesWithImageContext(
        _ messages: [LumiChatMessage],
        imageAttachments: [LumiImageAttachment]
    ) -> [LumiChatMessage] {
        guard !imageAttachments.isEmpty else {
            return messages
        }

        return messages.map { message in
            guard message.role == .user else {
                return message
            }

            var updated = message
            var metadata = updated.metadata
            metadata["hasImages"] = "true"
            if let encoded = Self.encodeImageAttachments(imageAttachments) {
                metadata["imageAttachments"] = encoded
            }
            updated.metadata = metadata

            if updated.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updated.content = "[\(imageAttachments.count) image(s) attached]"
            }
            return updated
        }
    }

    private static func encodeImageAttachments(_ attachments: [LumiImageAttachment]) -> String? {
        guard let data = try? JSONEncoder().encode(attachments),
              let json = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return json
    }

    private static func decodeToolArguments(_ json: String) throws -> [String: LumiJSONValue] {
        guard let data = json.data(using: .utf8), !data.isEmpty else {
            return [:]
        }
        return try JSONDecoder().decode([String: LumiJSONValue].self, from: data)
    }
}
