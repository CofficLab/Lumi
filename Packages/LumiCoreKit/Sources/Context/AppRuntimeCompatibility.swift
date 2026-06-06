import Combine
import Foundation
import AgentToolKit
import LLMKit
import LumiUI
import SwiftUI

public typealias ModelPreference = (providerId: String, model: String)

public enum ResponseVerbosity: CaseIterable, Codable, Identifiable, RawRepresentable, Sendable {
    case brief
    case standard
    case detailed

    public var id: String { rawValue }

    public var rawValue: String {
        switch self {
        case .brief:
            return "v1"
        case .standard:
            return "v2"
        case .detailed:
            return "v3"
        }
    }

    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "v1", "brief":
            self = .brief
        case "v2", "standard", "normal":
            self = .standard
        case "v3", "detailed":
            self = .detailed
        default:
            return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid response verbosity: \(rawValue)"
            )
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var levelCode: String {
        rawValue.uppercased()
    }

    public var displayName: String {
        switch self {
        case .brief:
            return "简洁"
        case .standard:
            return "标准"
        case .detailed:
            return "详细"
        }
    }

    public var iconName: String {
        switch self {
        case .brief:
            return "text.alignleft"
        case .standard:
            return "text.justify.left"
        case .detailed:
            return "doc.richtext"
        }
    }

    public var description: String {
        switch self {
        case .brief:
            return "只显示核心内容"
        case .standard:
            return "显示标准消息内容"
        case .detailed:
            return "显示模型、时间等详细信息"
        }
    }
}

public enum ChatMode: CaseIterable, Codable, Identifiable, RawRepresentable, Sendable {
    case chat
    case build
    case autonomous

    public var id: String { rawValue }

    public var rawValue: String {
        switch self {
        case .chat:
            return "a1"
        case .build:
            return "a2"
        case .autonomous:
            return "a3"
        }
    }

    public init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "a1", "ask", "chat":
            self = .chat
        case "a2", "build":
            self = .build
        case "a3", "autonomous":
            self = .autonomous
        default:
            return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid chat mode: \(rawValue)"
            )
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var levelCode: String {
        rawValue.uppercased()
    }

    public var iconName: String {
        switch self {
        case .chat:
            return "bubble.left.and.bubble.right"
        case .build:
            return "hammer"
        case .autonomous:
            return "bolt"
        }
    }

    public var displayName: String {
        switch self {
        case .chat:
            return "Chat"
        case .build:
            return "Build"
        case .autonomous:
            return "Auto"
        }
    }
}

@MainActor
public final class AppLLMVM: ObservableObject {
    @Published public var selectedProviderId: String {
        didSet {
            guard !isApplyingHostState, selectedProviderId != oldValue else { return }
            selectedProviderIdSetter(selectedProviderId)
        }
    }
    @Published public var currentModel: String {
        didSet {
            guard !isApplyingHostState, currentModel != oldValue else { return }
            currentModelSetter(currentModel)
        }
    }
    @Published public var isAutoMode: Bool {
        didSet {
            guard !isApplyingHostState, isAutoMode != oldValue else { return }
            isAutoModeSetter(isAutoMode)
        }
    }
    @Published public var lastAutoRouteSummary: String?
    @Published public var chatMode: ChatMode
    @Published public var verbosity: ResponseVerbosity

    public var llmService: LLMService
    public var providersProvider: @MainActor () -> [LLMProviderInfo]
    public var providerTypeProvider: @MainActor (String) -> (any SuperLLMProvider.Type)?
    public var providerFactory: @MainActor (String) -> (any SuperLLMProvider)?
    public var selectedProviderIdSetter: @MainActor (String) -> Void
    public var currentModelSetter: @MainActor (String) -> Void
    public var isAutoModeSetter: @MainActor (Bool) -> Void
    public var chatModeSetter: @MainActor (ChatMode) -> Void
    public var verbositySetter: @MainActor (ResponseVerbosity) -> Void
    private var isApplyingHostState = false
    private var hostStateCancellables: Set<AnyCancellable> = []

    public init(
        selectedProviderId: String = "",
        currentModel: String = "",
        isAutoMode: Bool = false,
        lastAutoRouteSummary: String? = nil,
        chatMode: ChatMode = .build,
        verbosity: ResponseVerbosity = .brief,
        llmService: LLMService = LLMService(),
        providersProvider: @escaping @MainActor () -> [LLMProviderInfo] = { [] },
        providerTypeProvider: @escaping @MainActor (String) -> (any SuperLLMProvider.Type)? = { _ in nil },
        providerFactory: @escaping @MainActor (String) -> (any SuperLLMProvider)? = { _ in nil },
        selectedProviderIdSetter: @escaping @MainActor (String) -> Void = { _ in },
        currentModelSetter: @escaping @MainActor (String) -> Void = { _ in },
        isAutoModeSetter: @escaping @MainActor (Bool) -> Void = { _ in },
        chatModeSetter: @escaping @MainActor (ChatMode) -> Void = { _ in },
        verbositySetter: @escaping @MainActor (ResponseVerbosity) -> Void = { _ in }
    ) {
        self.selectedProviderId = selectedProviderId
        self.currentModel = currentModel
        self.isAutoMode = isAutoMode
        self.lastAutoRouteSummary = lastAutoRouteSummary
        self.chatMode = chatMode
        self.verbosity = verbosity
        self.llmService = llmService
        self.providersProvider = providersProvider
        self.providerTypeProvider = providerTypeProvider
        self.providerFactory = providerFactory
        self.selectedProviderIdSetter = selectedProviderIdSetter
        self.currentModelSetter = currentModelSetter
        self.isAutoModeSetter = isAutoModeSetter
        self.chatModeSetter = chatModeSetter
        self.verbositySetter = verbositySetter
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
        return LLMConfig(model: model, providerId: providerId)
    }

    public func getCurrentConfig() -> LLMConfig {
        makeConfig(providerId: selectedProviderId, model: currentModel) ?? .default
    }

    public func setChatMode(_ chatMode: ChatMode) {
        guard self.chatMode != chatMode else { return }
        self.chatMode = chatMode
        chatModeSetter(chatMode)
    }

    public func setVerbosity(_ verbosity: ResponseVerbosity) {
        guard self.verbosity != verbosity else { return }
        self.verbosity = verbosity
        verbositySetter(verbosity)
    }

    public func updateChatModeFromHost(_ chatMode: ChatMode) {
        guard self.chatMode != chatMode else { return }
        self.chatMode = chatMode
    }

    public func updateVerbosityFromHost(_ verbosity: ResponseVerbosity) {
        guard self.verbosity != verbosity else { return }
        self.verbosity = verbosity
    }

    public func updateSelectedProviderIdFromHost(_ selectedProviderId: String) {
        applyHostState {
            self.selectedProviderId = selectedProviderId
        }
    }

    public func updateCurrentModelFromHost(_ currentModel: String) {
        applyHostState {
            self.currentModel = currentModel
        }
    }

    public func updateIsAutoModeFromHost(_ isAutoMode: Bool) {
        applyHostState {
            self.isAutoMode = isAutoMode
        }
    }

    public func updateLastAutoRouteSummaryFromHost(_ lastAutoRouteSummary: String?) {
        applyHostState {
            self.lastAutoRouteSummary = lastAutoRouteSummary
        }
    }

    public func retainHostStateSubscription(_ cancellable: AnyCancellable) {
        hostStateCancellables.insert(cancellable)
    }

    private func applyHostState(_ update: () -> Void) {
        isApplyingHostState = true
        defer { isApplyingHostState = false }
        update()
    }
}

public final class LLMService: @unchecked Sendable {
    public typealias SendMessageHandler = @Sendable ([ChatMessage], LLMConfig, [SuperAgentTool]?) async throws -> ChatMessage

    private let sendMessageHandler: SendMessageHandler
    private let providersProvider: @MainActor () -> [LLMProviderInfo]
    private let providerTypeProvider: @MainActor (String) -> (any SuperLLMProvider.Type)?
    private let providerFactory: @MainActor (String) -> (any SuperLLMProvider)?

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
        providerFactory: @escaping @MainActor (String) -> (any SuperLLMProvider)? = { _ in nil }
    ) {
        self.sendMessageHandler = sendMessageHandler
        self.providersProvider = providersProvider
        self.providerTypeProvider = providerTypeProvider
        self.providerFactory = providerFactory
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

}

public struct ToolProgressSnapshot: Sendable {
    public let totalLines: Int
    public let totalBytes: Int
    public let latestOutputPreview: String

    public init(
        totalLines: Int,
        totalBytes: Int,
        latestOutputPreview: String
    ) {
        self.totalLines = totalLines
        self.totalBytes = totalBytes
        self.latestOutputPreview = latestOutputPreview
    }
}

public typealias ToolProgressSnapshotProvider = @Sendable () async -> ToolProgressSnapshot?

public final class ToolService: @unchecked Sendable {
    public typealias ExecuteToolHandler = @Sendable (String, String, ToolExecutionContext) async throws -> String
    public typealias RegisterProgressSnapshotProviderHandler = @MainActor @Sendable (String, @escaping ToolProgressSnapshotProvider) -> Void

    public var tools: [SuperAgentTool]
    private let executeToolHandler: ExecuteToolHandler
    private let registerProgressSnapshotProviderHandler: RegisterProgressSnapshotProviderHandler

    public init(
        tools: [SuperAgentTool] = [],
        executeToolHandler: @escaping ExecuteToolHandler = { name, _, _ in
            "Tool '\(name)' is not available in this runtime context."
        },
        registerProgressSnapshotProviderHandler: @escaping RegisterProgressSnapshotProviderHandler = { _, _ in }
    ) {
        self.tools = tools
        self.executeToolHandler = executeToolHandler
        self.registerProgressSnapshotProviderHandler = registerProgressSnapshotProviderHandler
    }

    public func executeTool(
        named name: String,
        argumentsJSON: String,
        context: ToolExecutionContext
    ) async throws -> String {
        try await executeToolHandler(name, argumentsJSON, context)
    }

    @MainActor
    public func registerProgressSnapshotProvider(
        for toolName: String,
        provider: @escaping ToolProgressSnapshotProvider
    ) {
        registerProgressSnapshotProviderHandler(toolName, provider)
    }
}

public struct ChatCommandSuggestion: Identifiable, Equatable, Sendable {
    public let id: String
    public let command: String
    public let description: String
    public let category: String
    public let isSelected: Bool

    public init(
        id: String? = nil,
        command: String,
        description: String,
        category: String = "",
        isSelected: Bool = false
    ) {
        self.id = id ?? command
        self.command = command
        self.description = description
        self.category = category
        self.isSelected = isSelected
    }
}

@MainActor
public final class WindowConversationVM: ObservableObject {
    @Published public var windowId: UUID?
    @Published public var selectedConversationId: UUID?
    @Published public private(set) var pendingMessagesVersion: Int
    @Published public private(set) var attachmentVersion: Int
    @Published public private(set) var statusVersion: Int
    @Published public private(set) var draftText: String
    @Published public private(set) var commandSuggestionsVersion: Int

    public var currentPreferenceProvider: @MainActor () -> ModelPreference?
    public var preferenceProvider: @MainActor (UUID) -> ModelPreference?
    public var preferenceSaver: @MainActor (UUID?, String, String) -> Void
    public var chatModePreferenceProvider: @MainActor () -> ChatMode?
    public var verbosityPreferenceProvider: @MainActor () -> ResponseVerbosity?
    public var verbosityPreferenceSaver: @MainActor (ResponseVerbosity?) -> Void
    public var languagePreferenceProvider: @MainActor () -> LanguagePreference?
    public var languagePreferenceSaver: @MainActor (LanguagePreference?) -> Void
    public var messagesProvider: @MainActor (UUID) -> [ChatMessage]
    public var messagePageLoader: @MainActor (UUID, Int, Date?) async -> (messages: [ChatMessage], hasMore: Bool)
    public var messageCountProvider: @MainActor (UUID) async -> Int
    public var messageDeleteHandler: @MainActor ([UUID], UUID) async -> Int
    public var statusMessageProvider: @MainActor (UUID) -> ChatMessage?
    public var pendingMessagesProvider: @MainActor (UUID) -> [ChatMessage]
    public var pendingMessageRemover: @MainActor (UUID) -> Void
    public var pendingAttachmentsProvider: @MainActor () -> [AgentPendingImageAttachment]
    public var attachmentRemover: @MainActor (UUID) -> Void
    public var imageUploadHandler: @MainActor (URL) -> Void
    public var screenshotDataHandler: @MainActor (Data) -> Void
    public var draftTextAppender: @MainActor (String) -> Void
    public var draftTextSetter: @MainActor (String) -> Void
    public var textSubmitter: @MainActor (String) async -> Void
    public var textEnqueuer: @MainActor (String) -> Void
    public var commandSuggestionsProvider: @MainActor (String) -> [ChatCommandSuggestion]
    public var commandSuggestionsUpdater: @MainActor (String) -> Void
    public var commandSuggestionsVisibilityProvider: @MainActor () -> Bool
    public var currentCommandSuggestionProvider: @MainActor () -> ChatCommandSuggestion?
    public var commandSuggestionNextSelector: @MainActor () -> Void
    public var commandSuggestionPreviousSelector: @MainActor () -> Void
    public var commandSuggestionsVisibilitySetter: @MainActor (Bool) -> Void
    public var switchToLatestConversationHandler: @MainActor (String) -> Bool
    public var createNewConversationHandler: @MainActor (String?, String?, LanguagePreference, ChatMode?) async -> Void
    public var databaseDirectoryProvider: @MainActor () -> URL

    public init(
        windowId: UUID? = nil,
        selectedConversationId: UUID? = nil,
        pendingMessagesVersion: Int = 0,
        attachmentVersion: Int = 0,
        statusVersion: Int = 0,
        draftText: String = "",
        commandSuggestionsVersion: Int = 0,
        currentPreferenceProvider: @escaping @MainActor () -> ModelPreference? = { nil },
        preferenceProvider: @escaping @MainActor (UUID) -> ModelPreference? = { _ in nil },
        preferenceSaver: @escaping @MainActor (UUID?, String, String) -> Void = { _, _, _ in },
        chatModePreferenceProvider: @escaping @MainActor () -> ChatMode? = { nil },
        verbosityPreferenceProvider: @escaping @MainActor () -> ResponseVerbosity? = { nil },
        verbosityPreferenceSaver: @escaping @MainActor (ResponseVerbosity?) -> Void = { _ in },
        languagePreferenceProvider: @escaping @MainActor () -> LanguagePreference? = { nil },
        languagePreferenceSaver: @escaping @MainActor (LanguagePreference?) -> Void = { _ in },
        messagesProvider: @escaping @MainActor (UUID) -> [ChatMessage] = { _ in [] },
        messagePageLoader: @escaping @MainActor (UUID, Int, Date?) async -> (messages: [ChatMessage], hasMore: Bool) = { _, _, _ in ([], false) },
        messageCountProvider: @escaping @MainActor (UUID) async -> Int = { _ in 0 },
        messageDeleteHandler: @escaping @MainActor ([UUID], UUID) async -> Int = { _, _ in 0 },
        statusMessageProvider: @escaping @MainActor (UUID) -> ChatMessage? = { _ in nil },
        pendingMessagesProvider: @escaping @MainActor (UUID) -> [ChatMessage] = { _ in [] },
        pendingMessageRemover: @escaping @MainActor (UUID) -> Void = { _ in },
        pendingAttachmentsProvider: @escaping @MainActor () -> [AgentPendingImageAttachment] = { [] },
        attachmentRemover: @escaping @MainActor (UUID) -> Void = { _ in },
        imageUploadHandler: @escaping @MainActor (URL) -> Void = { _ in },
        screenshotDataHandler: @escaping @MainActor (Data) -> Void = { _ in },
        draftTextAppender: @escaping @MainActor (String) -> Void = { _ in },
        draftTextSetter: @escaping @MainActor (String) -> Void = { _ in },
        textSubmitter: @escaping @MainActor (String) async -> Void = { _ in },
        textEnqueuer: @escaping @MainActor (String) -> Void = { _ in },
        commandSuggestionsProvider: @escaping @MainActor (String) -> [ChatCommandSuggestion] = { _ in [] },
        commandSuggestionsUpdater: @escaping @MainActor (String) -> Void = { _ in },
        commandSuggestionsVisibilityProvider: @escaping @MainActor () -> Bool = { false },
        currentCommandSuggestionProvider: @escaping @MainActor () -> ChatCommandSuggestion? = { nil },
        commandSuggestionNextSelector: @escaping @MainActor () -> Void = {},
        commandSuggestionPreviousSelector: @escaping @MainActor () -> Void = {},
        commandSuggestionsVisibilitySetter: @escaping @MainActor (Bool) -> Void = { _ in },
        switchToLatestConversationHandler: @escaping @MainActor (String) -> Bool = { _ in false },
        createNewConversationHandler: @escaping @MainActor (String?, String?, LanguagePreference, ChatMode?) async -> Void = { _, _, _, _ in },
        databaseDirectoryProvider: @escaping @MainActor () -> URL = {
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
        }
    ) {
        self.windowId = windowId
        self.selectedConversationId = selectedConversationId
        self.pendingMessagesVersion = pendingMessagesVersion
        self.attachmentVersion = attachmentVersion
        self.statusVersion = statusVersion
        self.draftText = draftText
        self.commandSuggestionsVersion = commandSuggestionsVersion
        self.currentPreferenceProvider = currentPreferenceProvider
        self.preferenceProvider = preferenceProvider
        self.preferenceSaver = preferenceSaver
        self.chatModePreferenceProvider = chatModePreferenceProvider
        self.verbosityPreferenceProvider = verbosityPreferenceProvider
        self.verbosityPreferenceSaver = verbosityPreferenceSaver
        self.languagePreferenceProvider = languagePreferenceProvider
        self.languagePreferenceSaver = languagePreferenceSaver
        self.messagesProvider = messagesProvider
        self.messagePageLoader = messagePageLoader
        self.messageCountProvider = messageCountProvider
        self.messageDeleteHandler = messageDeleteHandler
        self.statusMessageProvider = statusMessageProvider
        self.pendingMessagesProvider = pendingMessagesProvider
        self.pendingMessageRemover = pendingMessageRemover
        self.pendingAttachmentsProvider = pendingAttachmentsProvider
        self.attachmentRemover = attachmentRemover
        self.imageUploadHandler = imageUploadHandler
        self.screenshotDataHandler = screenshotDataHandler
        self.draftTextAppender = draftTextAppender
        self.draftTextSetter = draftTextSetter
        self.textSubmitter = textSubmitter
        self.textEnqueuer = textEnqueuer
        self.commandSuggestionsProvider = commandSuggestionsProvider
        self.commandSuggestionsUpdater = commandSuggestionsUpdater
        self.commandSuggestionsVisibilityProvider = commandSuggestionsVisibilityProvider
        self.currentCommandSuggestionProvider = currentCommandSuggestionProvider
        self.commandSuggestionNextSelector = commandSuggestionNextSelector
        self.commandSuggestionPreviousSelector = commandSuggestionPreviousSelector
        self.commandSuggestionsVisibilitySetter = commandSuggestionsVisibilitySetter
        self.switchToLatestConversationHandler = switchToLatestConversationHandler
        self.createNewConversationHandler = createNewConversationHandler
        self.databaseDirectoryProvider = databaseDirectoryProvider
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

    public func getVerbosityPreference() -> ResponseVerbosity? {
        verbosityPreferenceProvider()
    }

    public func saveVerbosityPreference(_ verbosity: ResponseVerbosity?) {
        verbosityPreferenceSaver(verbosity)
    }

    public func getLanguagePreference() -> LanguagePreference? {
        languagePreferenceProvider()
    }

    public func saveLanguagePreference(_ languagePreference: LanguagePreference?) {
        languagePreferenceSaver(languagePreference)
    }

    public var hasSelectedConversation: Bool {
        selectedConversationId != nil
    }

    public func messages(for conversationId: UUID) -> [ChatMessage] {
        messagesProvider(conversationId)
    }

    public func loadMessagesPage(
        forConversationId conversationId: UUID,
        limit: Int,
        beforeTimestamp: Date? = nil
    ) async -> (messages: [ChatMessage], hasMore: Bool) {
        await messagePageLoader(conversationId, limit, beforeTimestamp)
    }

    public func getMessageCount(forConversationId conversationId: UUID) async -> Int {
        await messageCountProvider(conversationId)
    }

    public func deleteMessages(messageIds: [UUID], conversationId: UUID) async -> Int {
        await messageDeleteHandler(messageIds, conversationId)
    }

    public func currentMessages() -> [ChatMessage] {
        guard let selectedConversationId else { return [] }
        return messages(for: selectedConversationId)
    }

    public func statusMessage(for conversationId: UUID) -> ChatMessage? {
        statusMessageProvider(conversationId)
    }

    public func currentDisplayMessages() -> [ChatMessage] {
        guard let selectedConversationId else { return [] }
        var rows = messages(for: selectedConversationId)
        if let statusMessage = statusMessage(for: selectedConversationId),
           !rows.contains(where: { $0.id == statusMessage.id }) {
            rows.append(statusMessage)
        }
        return rows
    }

    public func pendingMessages(for conversationId: UUID) -> [ChatMessage] {
        pendingMessagesProvider(conversationId)
    }

    public func currentPendingMessages() -> [ChatMessage] {
        guard let selectedConversationId else { return [] }
        return pendingMessages(for: selectedConversationId)
    }

    public func removePendingMessage(id messageId: UUID) {
        pendingMessageRemover(messageId)
    }

    public func notifyPendingMessagesChanged() {
        pendingMessagesVersion += 1
    }

    public var pendingAttachments: [AgentPendingImageAttachment] {
        pendingAttachmentsProvider()
    }

    public var canAttachToCurrentConversation: Bool {
        hasSelectedConversation
    }

    public var canSubmitText: Bool {
        hasSelectedConversation || !pendingAttachments.isEmpty
    }

    public func removeAttachment(id attachmentId: UUID) {
        attachmentRemover(attachmentId)
    }

    public func handleImageUpload(url: URL) {
        imageUploadHandler(url)
    }

    public func handleScreenshotData(_ data: Data) {
        screenshotDataHandler(data)
    }

    public func appendDraftText(_ text: String) {
        let trimmedNewText = text.trimmingCharacters(in: .whitespaces)
        let needsLeadingSpace = !draftText.isEmpty && !draftText.hasSuffix(" ")
        let needsTrailingSpace = !trimmedNewText.hasSuffix(" ")
        var finalText = trimmedNewText
        if needsLeadingSpace {
            finalText = " " + finalText
        }
        if needsTrailingSpace {
            finalText += " "
        }
        draftText += finalText
        draftTextAppender(text)
    }

    public func setDraftText(_ text: String) {
        guard draftText != text else { return }
        draftText = text
        draftTextSetter(text)
    }

    public func updateDraftTextFromHost(_ text: String) {
        guard draftText != text else { return }
        draftText = text
    }

    public func submitDraftText(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSubmitText, !trimmed.isEmpty || !pendingAttachments.isEmpty else { return }
        updateDraftTextFromHost("")
        draftTextSetter("")
        await textSubmitter(trimmed)
    }

    public func enqueueText(_ text: String) {
        textEnqueuer(text)
    }

    public func commandSuggestions(for input: String) -> [ChatCommandSuggestion] {
        commandSuggestionsProvider(input)
    }

    public func updateCommandSuggestions(for input: String) {
        commandSuggestionsUpdater(input)
        commandSuggestionsVersion += 1
    }

    public var isCommandSuggestionVisible: Bool {
        commandSuggestionsVisibilityProvider()
    }

    public func currentCommandSuggestion() -> ChatCommandSuggestion? {
        currentCommandSuggestionProvider()
    }

    public func selectNextCommandSuggestion() {
        commandSuggestionNextSelector()
        commandSuggestionsVersion += 1
    }

    public func selectPreviousCommandSuggestion() {
        commandSuggestionPreviousSelector()
        commandSuggestionsVersion += 1
    }

    public func setCommandSuggestionsVisible(_ isVisible: Bool) {
        commandSuggestionsVisibilitySetter(isVisible)
        commandSuggestionsVersion += 1
    }

    public func notifyCommandSuggestionsChanged() {
        commandSuggestionsVersion += 1
    }

    public func notifyAttachmentsChanged() {
        attachmentVersion += 1
    }

    public func notifyStatusChanged() {
        statusVersion += 1
    }

    @discardableResult
    public func switchToLatestConversation(forProject projectId: String) -> Bool {
        switchToLatestConversationHandler(projectId)
    }

    public func createNewConversation(
        projectName: String? = nil,
        projectPath: String? = nil,
        languagePreference: LanguagePreference = .chinese,
        chatMode: ChatMode? = nil
    ) async {
        await createNewConversationHandler(projectName, projectPath, languagePreference, chatMode)
    }

    public func databaseDirectory() -> URL {
        databaseDirectoryProvider()
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
