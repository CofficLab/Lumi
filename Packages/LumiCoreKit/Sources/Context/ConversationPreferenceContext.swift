import Foundation

@MainActor
public struct ChatModePreferenceContext {
    public let currentMode: ChatMode
    public let selectedConversationId: UUID?
    public let conversationModeProvider: @MainActor () -> ChatMode?
    public let modeSaver: @MainActor (ChatMode) -> Void

    public init(
        currentMode: ChatMode,
        selectedConversationId: UUID?,
        conversationModeProvider: @escaping @MainActor () -> ChatMode?,
        modeSaver: @escaping @MainActor (ChatMode) -> Void
    ) {
        self.currentMode = currentMode
        self.selectedConversationId = selectedConversationId
        self.conversationModeProvider = conversationModeProvider
        self.modeSaver = modeSaver
    }

    public func restoredMode() -> ChatMode {
        conversationModeProvider() ?? currentMode
    }

    public func save(_ mode: ChatMode) {
        modeSaver(mode)
    }
}

@MainActor
public struct VerbosityPreferenceContext {
    public let currentVerbosity: ResponseVerbosity
    public let selectedConversationId: UUID?
    public let conversationVerbosityProvider: @MainActor () -> ResponseVerbosity?
    public let verbositySaver: @MainActor (ResponseVerbosity) -> Void

    public init(
        currentVerbosity: ResponseVerbosity,
        selectedConversationId: UUID?,
        conversationVerbosityProvider: @escaping @MainActor () -> ResponseVerbosity?,
        verbositySaver: @escaping @MainActor (ResponseVerbosity) -> Void
    ) {
        self.currentVerbosity = currentVerbosity
        self.selectedConversationId = selectedConversationId
        self.conversationVerbosityProvider = conversationVerbosityProvider
        self.verbositySaver = verbositySaver
    }

    public func restoredVerbosity() -> ResponseVerbosity {
        conversationVerbosityProvider() ?? currentVerbosity
    }

    public func save(_ verbosity: ResponseVerbosity) {
        verbositySaver(verbosity)
    }
}
