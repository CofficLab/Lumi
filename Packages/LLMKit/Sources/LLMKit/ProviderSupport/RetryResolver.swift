import Foundation
import HttpKit
import LumiKernel

public enum ErrorDispositionResolver {
    public static func disposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        if error is CancellationError {
            return .nonRetryable
        }

        if let providing = error as? LumiLLMErrorDispositionProviding {
            return providing.llmErrorDisposition
        }

        let decision = OpenAICompatibleProviderAdapter.retryDecision(
            for: error,
            statusCode: extractStatusCode(from: error),
            attempt: context.attempt,
            maxAttempts: context.maxAttempts
        )
        return LumiLLMErrorDisposition(
            isRetryable: decision.shouldRetry,
            retryDelaySeconds: decision.delaySeconds
        )
    }

    private static func extractStatusCode(from error: Error) -> Int? {
        if let httpError = error as? HTTPClientError,
           case let .httpError(statusCode, _) = httpError {
            return statusCode
        }
        if let llmError = error as? LLMServiceError,
           case let .requestFailed(_, statusCode) = llmError {
            return statusCode
        }
        if case let LumiLLMProviderSupportError.streamingFailed(message) = error {
            return LumiProviderHTTPErrorParsing.statusCode(from: message)
        }
        return nil
    }
}

public enum LumiProviderHTTPErrorParsing {
    public static func statusCode(from error: Error) -> Int? {
        if case LumiLLMProviderSupportError.missingAPIKey = error {
            return nil
        }
        if case let HTTPClientError.httpError(statusCode, _) = error {
            return statusCode
        }
        if case let LumiLLMProviderSupportError.streamingFailed(message) = error {
            return statusCode(from: message)
        }
        return nil
    }

    public static func statusCode(from text: String) -> Int? {
        let patterns = [
            #"HTTP 错误 \((\d+)\)"#,
            #"HTTP 错误（(\d+)）"#,
            #"HTTP error \((\d+)\)"#,
            #"HTTP (\d+)"#,
            #"\b(\d{3})\b"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text),
                  let code = Int(text[range]),
                  (100 ... 599).contains(code)
            else {
                continue
            }
            return code
        }

        return nil
    }
}

public enum LumiLLMProviderErrorSupport {
    public static func makeErrorMessage(
        providerID: String,
        conversationID: UUID,
        request: LumiLLMRequest,
        error: Error,
        disposition: LumiLLMErrorDisposition,
        renderKind: String?
    ) -> LumiChatMessage {
        let detail: LumiLLMFailureDetail
        var metadata: [String: String] = [:]

        if case let LumiLLMProviderSupportError.streamingFailed(message) = error {
            let split = LumiLLMTransportDetails.split(message)
            detail = LumiLLMFailureDetail(
                summary: split.summary,
                httpStatusCode: LumiProviderHTTPErrorParsing.statusCode(from: split.summary)
                    ?? LumiProviderHTTPErrorParsing.statusCode(from: message),
                transportDetails: nil
            )
            metadata = LumiLLMTransportDetails.metadata(from: split)
        } else {
            detail = LumiLLMFailureDetailResolver.resolve(from: error)
            if let transportDetails = detail.transportDetails {
                metadata[LumiLLMTransportMetadata.responseDetails] = transportDetails
            }
        }

        metadata.merge(disposition.metadataEntries) { _, new in new }
        return LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: providerID,
            modelName: request.model,
            isError: true,
            rawErrorDetail: detail.summary.isEmpty ? detail.availabilityDisplayText : detail.summary,
            renderKind: renderKind,
            metadata: metadata
        )
    }
}
