import Foundation
import HttpKit
import LLMKit
import LocalizationKit

public enum LLMFailureDetailResolver {
    public static func resolve(from error: Error, locale: Locale = .current) -> LumiLLMFailureDetail {
        if let supportError = error as? LumiLLMProviderSupportError {
            return resolve(from: supportError, locale: locale)
        }

        if let httpError = error as? HTTPClientError {
            return resolve(from: httpError, locale: locale)
        }

        if let localized = error as? LocalizedError,
           let description = localized.errorDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty {
            return .message(description)
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else {
            return .message(LLMProviderSupportLocalization.string("Request failed", locale: locale))
        }
        return .message(description)
    }

    private static func resolve(
        from error: LumiLLMProviderSupportError,
        locale: Locale
    ) -> LumiLLMFailureDetail {
        switch error {
        case .emptyConversation:
            return .message(
                LLMProviderSupportLocalization.string("LLM request has no conversation.", locale: locale)
            )
        case let .invalidBaseURL(url):
            return .message(
                LLMProviderSupportLocalization.format(
                    "Invalid provider base URL: %@",
                    locale: locale,
                    url
                )
            )
        case let .missingAPIKey(providerName):
            return .message(
                LLMProviderSupportLocalization.format(
                    "%@ API Key is not configured.",
                    locale: locale,
                    providerName
                )
            )
        case .allEndpointsFailed:
            return .message(
                LLMProviderSupportLocalization.string("All provider endpoints failed.", locale: locale)
            )
        case let .streamingFailed(message):
            return resolveStreamingFailed(message)
        case .emptyResponse:
            return .message(
                LLMProviderSupportLocalization.string("LLM returned an empty response.", locale: locale)
            )
        }
    }

    private static func resolve(from error: HTTPClientError, locale: Locale) -> LumiLLMFailureDetail {
        switch error {
        case let .jsonSerializationFailed(underlying):
            return .message(
                LLMProviderSupportLocalization.format(
                    "JSON serialization failed: %@",
                    locale: locale,
                    underlying.localizedDescription
                )
            )
        case let .requestFailed(underlying):
            return .message(
                LLMProviderSupportLocalization.format(
                    "Request failed: %@",
                    locale: locale,
                    underlying.localizedDescription
                )
            )
        case let .decodingFailed(underlying):
            return .message(
                LLMProviderSupportLocalization.format(
                    "Response decoding failed: %@",
                    locale: locale,
                    underlying.localizedDescription
                )
            )
        case .invalidResponse:
            return .message(LLMProviderSupportLocalization.string("Invalid response", locale: locale))
        case let .httpError(statusCode, message):
            let body = message.trimmingCharacters(in: .whitespacesAndNewlines)
            let summary = bodyExcerpt(from: body)
                ?? LLMProviderSupportLocalization.format(
                    "HTTP %d",
                    locale: locale,
                    statusCode
                )
            return LumiLLMFailureDetail(
                summary: summary,
                httpStatusCode: statusCode,
                transportDetails: body.isEmpty ? nil : body
            )
        }
    }

    private static func resolveStreamingFailed(_ message: String) -> LumiLLMFailureDetail {
        let split = LLMTransportDetails.split(message)
        let summary = split.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let statusCode = LLMHTTPErrorParsing.statusCode(from: summary)
            ?? LLMHTTPErrorParsing.statusCode(from: message)

        if split.hasTransportDetails {
            return LumiLLMFailureDetail(
                summary: summary,
                httpStatusCode: statusCode,
                transportDetails: nil
            )
        }

        return LumiLLMFailureDetail(
            summary: summary.isEmpty ? message : summary,
            httpStatusCode: statusCode,
            transportDetails: nil
        )
    }

    private static func bodyExcerpt(from body: String) -> String? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let maxLength = 240
        if trimmed.count <= maxLength {
            return trimmed
        }
        return String(trimmed.prefix(maxLength)) + "..."
    }
}
