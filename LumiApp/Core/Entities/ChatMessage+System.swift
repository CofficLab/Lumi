import Foundation

// MARK: - 内置系统消息占位键与工厂

extension ChatMessage {
    // MARK: 占位键

    static var apiKeyMissingSystemContentKey: String { "__LUMI_API_KEY_MISSING__" }
    static var llmModelEmptyContentKey: String { "__LUMI_LLM_MODEL_EMPTY__" }
    static var llmProviderIdEmptyContentKey: String { "__LUMI_LLM_PROVIDER_ID_EMPTY__" }
    static var llmTemperatureInvalidContentKey: String { "__LUMI_LLM_TEMPERATURE_INVALID__" }
    static var llmMaxTokensInvalidContentKey: String { "__LUMI_LLM_MAX_TOKENS_INVALID__" }
    static var llmProviderNotFoundContentKey: String { "__LUMI_LLM_PROVIDER_NOT_FOUND__" }
    static var llmInvalidBaseURLContentKey: String { "__LUMI_LLM_INVALID_BASE_URL__" }
    static var loadingLocalModelSystemContentKey: String { "__LUMI_LOADING_LOCAL_MODEL__" }
    static var loadingLocalModelDoneSystemContentKey: String { "__LUMI_LOADING_LOCAL_MODEL_DONE__" }
    static var loadingLocalModelFailedSystemContentKey: String { "__LUMI_LOADING_LOCAL_MODEL_FAILED__" }
    static var turnCompletedSystemContentKey: String { "__LUMI_TURN_COMPLETED__" }

    // MARK: 工厂

    static func apiKeyMissingSystemMessage(languagePreference: LanguagePreference) -> ChatMessage {
        ChatMessage(
            role: .system,
            content: Self.apiKeyMissingSystemContentKey,
            isError: true
        )
    }

    static func llmInvalidBaseURLMessageContent(baseURL: String) -> String {
        llmInvalidBaseURLContentKey + "\n" + baseURL
    }

    static func llmInvalidBaseURLPayload(fromContent content: String) -> String? {
        guard content.hasPrefix(llmInvalidBaseURLContentKey + "\n") else { return nil }
        let rest = content.dropFirst(llmInvalidBaseURLContentKey.count + 1)
        let s = String(rest).trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }

    static func loadingLocalModelSystemMessage(
        languagePreference: LanguagePreference,
        providerId: String? = nil,
        modelName: String? = nil
    ) -> ChatMessage {
        ChatMessage(
            role: .system,
            content: Self.loadingLocalModelSystemContentKey,
            providerId: providerId,
            modelName: modelName
        )
    }

    static func turnCompletedSystemMessage(languagePreference: LanguagePreference) -> ChatMessage {
        ChatMessage(
            role: .status,
            content: Self.turnCompletedSystemContentKey
        )
    }
}
