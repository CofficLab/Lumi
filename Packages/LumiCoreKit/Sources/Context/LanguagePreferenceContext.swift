import AgentToolKit
import Foundation

@MainActor
public struct LanguagePreferenceContext {
    public let currentLanguage: LanguagePreference
    public let selectedConversationId: UUID?
    public let conversationLanguageProvider: @MainActor () -> LanguagePreference?
    public let languageSaver: @MainActor (LanguagePreference) -> Void

    public init(
        currentLanguage: LanguagePreference,
        selectedConversationId: UUID? = nil,
        conversationLanguageProvider: @escaping @MainActor () -> LanguagePreference? = { nil },
        languageSaver: @escaping @MainActor (LanguagePreference) -> Void = { _ in }
    ) {
        self.currentLanguage = currentLanguage
        self.selectedConversationId = selectedConversationId
        self.conversationLanguageProvider = conversationLanguageProvider
        self.languageSaver = languageSaver
    }

    public func restoredLanguage() -> LanguagePreference {
        conversationLanguageProvider() ?? currentLanguage
    }

    public func save(_ language: LanguagePreference) {
        languageSaver(language)
    }
}
