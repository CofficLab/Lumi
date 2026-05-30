import Foundation

public extension ChatMessage {
    static var loadingLocalModelSystemContentKey: String { "__LUMI_LOADING_LOCAL_MODEL__" }
    static var loadingLocalModelDoneSystemContentKey: String { "__LUMI_LOADING_LOCAL_MODEL_DONE__" }
    static var turnCompletedSystemContentKey: String { "__LUMI_TURN_COMPLETED__" }

    static var apiKeyMissingSystemContentKey: String { "__LUMI_API_KEY_MISSING__" }
    static var llmModelEmptyContentKey: String { "__LUMI_LLM_MODEL_EMPTY__" }
    static var llmProviderIdEmptyContentKey: String { "__LUMI_LLM_PROVIDER_ID_EMPTY__" }
    static var llmTemperatureInvalidContentKey: String { "__LUMI_LLM_TEMPERATURE_INVALID__" }
    static var llmMaxTokensInvalidContentKey: String { "__LUMI_LLM_MAX_TOKENS_INVALID__" }
    static var llmProviderNotFoundContentKey: String { "__LUMI_LLM_PROVIDER_NOT_FOUND__" }
    static var llmInvalidBaseURLContentKey: String { "__LUMI_LLM_INVALID_BASE_URL__" }
    static var loadingLocalModelFailedSystemContentKey: String { "__LUMI_LOADING_LOCAL_MODEL_FAILED__" }
    static var apiRequestFailedErrorKey: String { "__LUMI_API_REQUEST_FAILED__" }
    static var networkConnectionErrorKey: String { "__LUMI_NETWORK_CONNECTION_ERROR__" }
    static var parsingErrorKey: String { "__LUMI_PARSING_ERROR__" }
    static var authenticationErrorKey: String { "__LUMI_AUTHENTICATION_ERROR__" }
    static var quotaExceededErrorKey: String { "__LUMI_QUOTA_EXCEEDED__" }
    static var modelNotAvailableErrorKey: String { "__LUMI_MODEL_NOT_AVAILABLE__" }

    static func llmInvalidBaseURLMessageContent(baseURL: String) -> String {
        llmInvalidBaseURLContentKey + "\n" + baseURL
    }

    static func llmInvalidBaseURLPayload(fromContent content: String) -> String? {
        guard content.hasPrefix(llmInvalidBaseURLContentKey + "\n") else { return nil }
        let rest = content.dropFirst(llmInvalidBaseURLContentKey.count + 1)
        let value = String(rest).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
