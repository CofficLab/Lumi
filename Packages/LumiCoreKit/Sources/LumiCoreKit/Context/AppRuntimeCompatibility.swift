import Combine
import Foundation
import AgentToolKit
import LLMKit
import LumiUI
import SwiftUI

public typealias ModelPreference = (providerId: String, model: String)

public enum ChatMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case build
    case ask

    public var id: String { rawValue }
}

@MainActor
public final class AppLLMVM: ObservableObject {
    @Published public var selectedProviderId: String
    @Published public var currentModel: String
    @Published public var isAutoMode: Bool
    @Published public var lastAutoRouteSummary: String?
    @Published public var chatMode: ChatMode

    public var llmService: LLMService
    public var providersProvider: @MainActor () -> [LLMProviderInfo]
    public var providerTypeProvider: @MainActor (String) -> (any SuperLLMProvider.Type)?
    public var providerFactory: @MainActor (String) -> (any SuperLLMProvider)?
    public var apiKeyProvider: @MainActor (String) -> String

    public init(
        selectedProviderId: String = "",
        currentModel: String = "",
        isAutoMode: Bool = false,
        lastAutoRouteSummary: String? = nil,
        chatMode: ChatMode = .build,
        llmService: LLMService = LLMService(),
        providersProvider: @escaping @MainActor () -> [LLMProviderInfo] = { [] },
        providerTypeProvider: @escaping @MainActor (String) -> (any SuperLLMProvider.Type)? = { _ in nil },
        providerFactory: @escaping @MainActor (String) -> (any SuperLLMProvider)? = { _ in nil },
        apiKeyProvider: @escaping @MainActor (String) -> String = { _ in "" }
    ) {
        self.selectedProviderId = selectedProviderId
        self.currentModel = currentModel
        self.isAutoMode = isAutoMode
        self.lastAutoRouteSummary = lastAutoRouteSummary
        self.chatMode = chatMode
        self.llmService = llmService
        self.providersProvider = providersProvider
        self.providerTypeProvider = providerTypeProvider
        self.providerFactory = providerFactory
        self.apiKeyProvider = apiKeyProvider
    }

    public var availableProviders: [LLMProviderInfo] { providersProvider() }
    public var allProviders: [LLMProviderInfo] { providersProvider() }

    public func providerType(forId id: String) -> (any SuperLLMProvider.Type)? {
        providerTypeProvider(id)
    }

    public func createProvider(id: String) -> (any SuperLLMProvider)? {
        providerFactory(id)
    }

    public func makeConfig(providerId: String, model: String) -> LLMConfig? {
        guard !providerId.isEmpty, !model.isEmpty else { return nil }
        return LLMConfig(apiKey: "", model: model, providerId: providerId)
    }

    public func getCurrentConfig() -> LLMConfig {
        makeConfig(providerId: selectedProviderId, model: currentModel) ?? .default
    }

    public func getApiKey(for providerId: String) -> String {
        apiKeyProvider(providerId)
    }

    public func setChatMode(_ chatMode: ChatMode) {
        self.chatMode = chatMode
    }
}

public final class LLMService: @unchecked Sendable {
    public typealias SendMessageHandler = @Sendable ([ChatMessage], LLMConfig, [SuperAgentTool]?) async throws -> ChatMessage

    private let sendMessageHandler: SendMessageHandler
    private let providersProvider: @MainActor () -> [LLMProviderInfo]
    private let providerTypeProvider: @MainActor (String) -> (any SuperLLMProvider.Type)?
    private let providerFactory: @MainActor (String) -> (any SuperLLMProvider)?
    private let apiKeyProvider: @MainActor (String) -> String

    public init(
        sendMessageHandler: @escaping SendMessageHandler = { messages, _, _ in
            ChatMessage(
                role: .assistant,
                conversationId: messages.last?.conversationId ?? UUID(),
                content: ""
            )
        },
        providersProvider: @escaping @MainActor () -> [LLMProviderInfo] = { [] },
        providerTypeProvider: @escaping @MainActor (String) -> (any SuperLLMProvider.Type)? = { _ in nil },
        providerFactory: @escaping @MainActor (String) -> (any SuperLLMProvider)? = { _ in nil },
        apiKeyProvider: @escaping @MainActor (String) -> String = { _ in "" }
    ) {
        self.sendMessageHandler = sendMessageHandler
        self.providersProvider = providersProvider
        self.providerTypeProvider = providerTypeProvider
        self.providerFactory = providerFactory
        self.apiKeyProvider = apiKeyProvider
    }

    public func sendMessage(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]? = nil
    ) async throws -> ChatMessage {
        try await sendMessageHandler(messages, config, tools)
    }

    @MainActor
    public func allProviders() -> [LLMProviderInfo] {
        providersProvider()
    }

    @MainActor
    public func providerType(forId id: String) -> (any SuperLLMProvider.Type)? {
        providerTypeProvider(id)
    }

    @MainActor
    public func createProvider(id: String) -> (any SuperLLMProvider)? {
        providerFactory(id)
    }

    @MainActor
    public func getApiKey(for providerId: String) -> String {
        apiKeyProvider(providerId)
    }
}

public final class ToolService: @unchecked Sendable {
    public typealias ExecuteToolHandler = @Sendable (String, String, ToolExecutionContext) async throws -> String

    public var tools: [SuperAgentTool]
    private let executeToolHandler: ExecuteToolHandler

    public init(
        tools: [SuperAgentTool] = [],
        executeToolHandler: @escaping ExecuteToolHandler = { name, _, _ in
            "Tool '\(name)' is not available in this runtime context."
        }
    ) {
        self.tools = tools
        self.executeToolHandler = executeToolHandler
    }

    public func executeTool(
        named name: String,
        argumentsJSON: String,
        context: ToolExecutionContext
    ) async throws -> String {
        try await executeToolHandler(name, argumentsJSON, context)
    }
}

@MainActor
public final class WindowConversationVM: ObservableObject {
    @Published public var selectedConversationId: UUID?

    public var currentPreferenceProvider: @MainActor () -> ModelPreference?
    public var preferenceProvider: @MainActor (UUID) -> ModelPreference?
    public var preferenceSaver: @MainActor (UUID?, String, String) -> Void
    public var chatModePreferenceProvider: @MainActor () -> ChatMode?
    public var messagesProvider: @MainActor (UUID) -> [ChatMessage]
    public var switchToLatestConversationHandler: @MainActor (String) -> Bool
    public var createNewConversationHandler: @MainActor (String?, String?, LanguagePreference) async -> Void

    public init(
        selectedConversationId: UUID? = nil,
        currentPreferenceProvider: @escaping @MainActor () -> ModelPreference? = { nil },
        preferenceProvider: @escaping @MainActor (UUID) -> ModelPreference? = { _ in nil },
        preferenceSaver: @escaping @MainActor (UUID?, String, String) -> Void = { _, _, _ in },
        chatModePreferenceProvider: @escaping @MainActor () -> ChatMode? = { nil },
        messagesProvider: @escaping @MainActor (UUID) -> [ChatMessage] = { _ in [] },
        switchToLatestConversationHandler: @escaping @MainActor (String) -> Bool = { _ in false },
        createNewConversationHandler: @escaping @MainActor (String?, String?, LanguagePreference) async -> Void = { _, _, _ in }
    ) {
        self.selectedConversationId = selectedConversationId
        self.currentPreferenceProvider = currentPreferenceProvider
        self.preferenceProvider = preferenceProvider
        self.preferenceSaver = preferenceSaver
        self.chatModePreferenceProvider = chatModePreferenceProvider
        self.messagesProvider = messagesProvider
        self.switchToLatestConversationHandler = switchToLatestConversationHandler
        self.createNewConversationHandler = createNewConversationHandler
    }

    public func getModelPreference() -> ModelPreference? {
        currentPreferenceProvider()
    }

    public func getModelPreference(for conversationId: UUID) -> ModelPreference? {
        preferenceProvider(conversationId)
    }

    public func saveModelPreference(providerId: String, model: String) {
        preferenceSaver(nil, providerId, model)
    }

    public func saveModelPreference(for conversationId: UUID, providerId: String, model: String) {
        preferenceSaver(conversationId, providerId, model)
    }

    public func getChatModePreference() -> ChatMode? {
        chatModePreferenceProvider()
    }

    public var hasSelectedConversation: Bool {
        selectedConversationId != nil
    }

    public func messages(for conversationId: UUID) -> [ChatMessage] {
        messagesProvider(conversationId)
    }

    public func currentMessages() -> [ChatMessage] {
        guard let selectedConversationId else { return [] }
        return messages(for: selectedConversationId)
    }

    @discardableResult
    public func switchToLatestConversation(forProject projectId: String) -> Bool {
        switchToLatestConversationHandler(projectId)
    }

    public func createNewConversation(
        projectName: String? = nil,
        projectPath: String? = nil,
        languagePreference: LanguagePreference = .chinese
    ) async {
        await createNewConversationHandler(projectName, projectPath, languagePreference)
    }
}

@MainActor
public final class AppPluginVM: ObservableObject {
    public init() {}

    public func isActiveViewContainerIcon(_ activeIcon: String?, in allowedIcons: [String]) -> Bool {
        guard let activeIcon else { return false }
        return allowedIcons.contains(activeIcon)
    }
}

@MainActor
public final class AppGitVM: ObservableObject {
    @Published public private(set) var selectedCommitHash: String?
    @Published public private(set) var selectedCommitFile: String?
    @Published public private(set) var unpushedCommitHashes: Set<String>
    @Published public private(set) var unpushedCommitsCount: Int

    public init(
        selectedCommitHash: String? = nil,
        selectedCommitFile: String? = nil,
        unpushedCommitHashes: Set<String> = []
    ) {
        self.selectedCommitHash = selectedCommitHash
        self.selectedCommitFile = selectedCommitFile
        self.unpushedCommitHashes = unpushedCommitHashes
        self.unpushedCommitsCount = unpushedCommitHashes.count
    }

    public func selectCommit(hash: String?) {
        selectedCommitHash = hash
    }

    public func clearSelection() {
        selectedCommitHash = nil
    }

    public func selectCommitFile(_ file: String?) {
        selectedCommitFile = file
    }

    public func updateUnpushedCommitHashes(_ hashes: [String]) {
        unpushedCommitHashes = Set(hashes)
        unpushedCommitsCount = hashes.count
    }

    public func clearUnpushedCommits() {
        unpushedCommitHashes = []
        unpushedCommitsCount = 0
    }

    public func isCommitUnpushed(_ commitHash: String) -> Bool {
        unpushedCommitHashes.contains(commitHash)
    }
}

@MainActor
public final class AppChatHistoryVM: ObservableObject {
    public init() {}
}

@MainActor
public final class AppThemeVM: ObservableObject {
    public init() {}

    public var activeChromeTheme: any LumiAppChromeTheme {
        ActiveChromeTheme.current
    }
}
