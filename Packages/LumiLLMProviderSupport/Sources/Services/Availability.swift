import Foundation
import HttpKit
import LLMKit
import LumiCoreLLMProvider
import LumiCoreMessage

enum LumiLLMProviderAvailabilitySupport {
    static let pingMaxTokens = 1

    static func applyPingTokenLimit(to body: inout [String: Any]) {
        body["max_tokens"] = pingMaxTokens
    }

    static func chatPing(
        model: String,
        baseURL: String,
        apiService: LLMAPIService,
        buildRequestBody: (String) throws -> [String: Any],
        buildRequest: (URL, String) -> URLRequest,
        resolveAPIKey: () throws -> String
    ) async -> LumiModelAvailabilityResult {
        let apiKeyValue: String
        do {
            apiKeyValue = try resolveAPIKey()
        } catch {
            return .unavailable(LumiLLMFailureDetailResolver.resolve(from: error))
        }

        guard let url = URL(string: baseURL) else {
            return .unavailable(.message("Invalid Base URL"))
        }

        let body: [String: Any]
        do {
            var builtBody = try buildRequestBody(model)
            applyPingTokenLimit(to: &builtBody)
            body = builtBody
        } catch {
            return .unavailable(.message(error.localizedDescription))
        }

        let httpRequest = buildRequest(url, apiKeyValue)

        do {
            _ = try await apiService.sendChatRequest(
                request: httpRequest,
                body: body
            )
            return .available
        } catch {
            let detail = LumiLLMFailureDetailResolver.resolve(from: error)
            return .unavailable(detail)
        }
    }
}
