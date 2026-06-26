import Foundation
import HttpKit
import LumiCoreKit

public enum LumiLLMFailureDetailResolver {
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
            return .message(LumiLLMProviderSupportLocalization.string("Request failed", locale: locale))
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
                LumiLLMProviderSupportLocalization.string("LLM request has no conversation.", locale: locale)
            )
        case let .invalidBaseURL(url):
            return .message(
                LumiLLMProviderSupportLocalization.format(
                    "Invalid provider base URL: %@",
                    locale: locale,
                    url
                )
            )
        case let .missingAPIKey(providerName):
            return .message(
                LumiLLMProviderSupportLocalization.format(
                    "%@ API Key is not configured.",
                    locale: locale,
                    providerName
                )
            )
        case .allEndpointsFailed:
            return .message(
                LumiLLMProviderSupportLocalization.string("All provider endpoints failed.", locale: locale)
            )
        case let .streamingFailed(message):
            return resolveStreamingFailed(message)
        }
    }

    private static func resolve(from error: HTTPClientError, locale: Locale) -> LumiLLMFailureDetail {
        switch error {
        case let .jsonSerializationFailed(underlying):
            return .message(
                LumiLLMProviderSupportLocalization.format(
                    "JSON serialization failed: %@",
                    locale: locale,
                    underlying.localizedDescription
                )
            )
        case let .requestFailed(underlying):
            return .message(
                LumiLLMProviderSupportLocalization.format(
                    "Request failed: %@",
                    locale: locale,
                    underlying.localizedDescription
                )
            )
        case let .decodingFailed(underlying):
            return .message(
                LumiLLMProviderSupportLocalization.format(
                    "Response decoding failed: %@",
                    locale: locale,
                    underlying.localizedDescription
                )
            )
        case .invalidResponse:
            return .message(LumiLLMProviderSupportLocalization.string("Invalid response", locale: locale))
        case let .httpError(statusCode, message):
            return LumiLLMFailureDetail(
                summary: responseExcerpt(from: message) ?? "",
                httpStatusCode: statusCode,
                transportDetails: message
            )
        }
    }

    private static func resolveStreamingFailed(_ message: String) -> LumiLLMFailureDetail {
        let split = LumiLLMTransportDetails.split(message)
        let summary = split.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let statusCode = LumiLLMHTTPErrorParsing.statusCode(from: summary)
            ?? LumiLLMHTTPErrorParsing.statusCode(from: message)

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

    private static func responseExcerpt(from transportMessage: String) -> String? {
        guard let range = transportMessage.range(of: "Response:") else {
            return nil
        }

        let response = transportMessage[range.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !response.isEmpty else { return nil }

        let maxLength = 240
        if response.count <= maxLength {
            return response
        }
        return String(response.prefix(maxLength)) + "..."
    }
}
