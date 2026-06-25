import Foundation
import HttpKit
import LumiCoreKit

public enum LumiLLMProviderSupportLocalization {
    static func string(_ key: String, locale: Locale = .current) -> String {
        LumiPluginLocalization.string(key, bundle: .module, locale: locale)
    }

    static func format(_ key: String, locale: Locale = .current, _ arguments: CVarArg...) -> String {
        let template = string(key, locale: locale)
        return String(format: template, locale: locale, arguments: arguments)
    }

    static func httpError(statusCode: Int, message: String, locale: Locale = .current) -> String {
        format("HTTP error (%lld): %@", locale: locale, Int64(statusCode), message)
    }

    public static func userFacingDescription(for error: Error, locale: Locale = .current) -> String {
        if let supportError = error as? LumiLLMProviderSupportError {
            return supportError.localizedDescription(locale: locale)
        }

        if let httpError = error as? HTTPClientError {
            return userFacingDescription(for: httpError, locale: locale)
        }

        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }

        return error.localizedDescription
    }

    private static func userFacingDescription(for error: HTTPClientError, locale: Locale) -> String {
        switch error {
        case let .jsonSerializationFailed(underlying):
            return format("JSON serialization failed: %@", locale: locale, underlying.localizedDescription)
        case let .requestFailed(underlying):
            return format("Request failed: %@", locale: locale, underlying.localizedDescription)
        case let .decodingFailed(underlying):
            return format("Response decoding failed: %@", locale: locale, underlying.localizedDescription)
        case .invalidResponse:
            return string("Invalid response", locale: locale)
        case let .httpError(statusCode, message):
            return httpError(statusCode: statusCode, message: message, locale: locale)
        }
    }
}

extension LumiLLMProviderSupportError {
    func localizedDescription(locale: Locale) -> String {
        switch self {
        case .emptyConversation:
            return LumiLLMProviderSupportLocalization.string("LLM request has no conversation.", locale: locale)
        case let .invalidBaseURL(url):
            return LumiLLMProviderSupportLocalization.format(
                "Invalid provider base URL: %@",
                locale: locale,
                url
            )
        case let .missingAPIKey(providerName):
            return LumiLLMProviderSupportLocalization.format(
                "%@ API Key is not configured.",
                locale: locale,
                providerName
            )
        case .allEndpointsFailed:
            return LumiLLMProviderSupportLocalization.string("All provider endpoints failed.", locale: locale)
        case let .streamingFailed(message):
            return message
        }
    }
}
