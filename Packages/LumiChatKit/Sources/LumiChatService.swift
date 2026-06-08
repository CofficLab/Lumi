import Foundation
import LumiCoreKit

@MainActor
public final class LumiChatService: ObservableObject, LumiChatServicing {
    @Published public private(set) var conversations: [LumiConversationSummary]
    @Published public private(set) var selectedConversationID: UUID?
    @Published public private(set) var providerInfos: [LumiLLMProviderInfo] = []
    @Published public private(set) var selectedProviderID: String?
    @Published public private(set) var selectedModel: String?
    @Published public private(set) var messageRenderers: [LumiMessageRendererItem] = []
    @Published public private(set) var revision: Int = 0

    private var messagesByConversationID: [UUID: [LumiChatMessage]]
    private var providersByID: [String: any LumiLLMProvider] = [:]
    private var middlewares: [any LumiSendMiddleware] = []
    private weak var toolService: (any LumiToolServicing)?
    private let store: LumiChatStore
    private let maxToolIterations = 4

    public init(configuration: LumiChatConfiguration) {
        self.store = LumiChatStore(configuration: configuration)
        let snapshot = store.load()
        self.conversations = snapshot.conversations
        self.messagesByConversationID = Self.messagesByMergingToolResults(snapshot.messagesByConversationID)
        self.selectedConversationID = snapshot.selectedConversationID
        self.selectedProviderID = snapshot.selectedProviderID
        self.selectedModel = snapshot.selectedModel
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
        conversations.removeAll { $0.id == id }
        messagesByConversationID[id] = nil

        if selectedConversationID == id {
            selectedConversationID = conversations.first?.id
        }

        persist()
    }

    public func selectProvider(id: String, model: String? = nil) {
        guard let info = providerInfos.first(where: { $0.id == id }) else {
            return
        }

        selectedProviderID = info.id
        selectedModel = normalizedModel(model, for: info)
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

    public func renderer(for message: LumiChatMessage) -> LumiMessageRendererItem? {
        messageRenderers.first { $0.canRender(message) }
    }

    public func send(_ text: String, in conversationID: UUID?) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        let targetID = conversationID ?? selectedConversationID ?? createConversation(title: title(from: trimmed))
        if selectedConversationID != targetID {
            selectConversation(id: targetID)
        }

        append(
            LumiChatMessage(
                conversationID: targetID,
                role: .user,
                content: trimmed
            )
        )

        await runAgentTurn(conversationID: targetID)
    }

    private func runAgentTurn(conversationID: UUID) async {
        for _ in 0..<maxToolIterations {
            let requestMessages = messages(for: conversationID)
            let expandedMessages = messagesByExpandingToolResults(requestMessages)
            let preparedMessages = await prepareMessages(expandedMessages, conversationID: conversationID)
            let assistantMessage = await makeAssistantMessage(
                conversationID: conversationID,
                messages: messagesWithConversationPreferences(preparedMessages, conversationID: conversationID)
            )
            append(assistantMessage)

            guard let toolCalls = assistantMessage.toolCalls,
                  !toolCalls.isEmpty,
                  let toolService
            else {
                return
            }

            for toolCall in toolCalls {
                let result = await toolService.execute(toolCall, conversationID: conversationID)
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

    private func prepareMessages(
        _ messages: [LumiChatMessage],
        conversationID: UUID
    ) async -> [LumiChatMessage] {
        var context = LumiSendContext(conversationID: conversationID, messages: messages)
        for middleware in middlewares {
            do {
                context = try await middleware.prepare(context)
            } catch {
                return messages
            }
        }
        return context.messages
    }

    private func makeAssistantMessage(
        conversationID: UUID,
        messages: [LumiChatMessage]
    ) async -> LumiChatMessage {
        if let provider = selectedProvider {
            let providerInfo = type(of: provider).info
            do {
                return try await provider.send(
                    LumiLLMRequest(
                        messages: messages,
                        model: selectedModel ?? providerInfo.defaultModel,
                        tools: agentTools
                    )
                )
            } catch {
                return LumiChatMessage(
                    conversationID: conversationID,
                    role: .error,
                    content: error.localizedDescription,
                    providerID: providerInfo.id,
                    modelName: selectedModel ?? providerInfo.defaultModel,
                    isError: true,
                    rawErrorDetail: error.localizedDescription
                )
            }
        }

        return LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "Chat core is ready. LLM providers will be connected by plugins."
        )
    }

    private func messagesWithConversationPreferences(
        _ messages: [LumiChatMessage],
        conversationID: UUID
    ) -> [LumiChatMessage] {
        let language = language(for: conversationID)
        let automationLevel = automationLevel(for: conversationID)
        let verbosity = verbosity(for: conversationID)
        let systemMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .system,
            content: [
                language.systemPromptFragment,
                automationLevel.systemPromptFragment,
                verbosity.systemPromptFragment
            ].joined(separator: "\n"),
            metadata: [
                "source": "lumi-conversation-preferences",
                "language": language.rawValue,
                "automationLevel": automationLevel.rawValue,
                "verbosity": verbosity.rawValue
            ]
        )

        return [systemMessage] + messages
    }

    private var selectedProvider: (any LumiLLMProvider)? {
        guard let selectedProviderID else {
            return nil
        }
        return providersByID[selectedProviderID]
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
                selectedModel: selectedModel
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
}
