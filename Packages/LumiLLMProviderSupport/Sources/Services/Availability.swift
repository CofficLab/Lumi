import Foundation
import HttpKit
import LLMKit
import LLMKit
import LumiCoreKit

public enum LumiOpenAICompatibleAvailability {
    public static func chatPing(
        model: String,
        adapter: OpenAICompatibleProviderAdapter,
        apiService: LLMAPIService,
        buildRequest: (URL, String) -> URLRequest,
        resolveAPIKey: () throws -> String
    ) async -> LumiModelAvailabilityResult {
        await LumiLLMProviderAvailabilitySupport.chatPing(
            model: model,
            baseURL: adapter.configuration.baseURL,
            apiService: apiService,
            buildRequestBody: { model in
                try adapter.buildRequestBody(
                    messages: [ChatMessage(role: .user, content: "ping")],
                    model: model,
                    tools: nil,
                    systemPrompt: ""
                )
            },
            buildRequest: buildRequest,
            resolveAPIKey: resolveAPIKey
        )
    }
}

public enum LumiAnthropicCompatibleAvailability {
    public static func chatPing(
        model: String,
        adapter: AnthropicCompatibleProviderAdapter,
        apiService: LLMAPIService,
        buildRequest: (URL, String) -> URLRequest,
        resolveAPIKey: () throws -> String
    ) async -> LumiModelAvailabilityResult {
        await LumiLLMProviderAvailabilitySupport.chatPing(
            model: model,
            baseURL: adapter.configuration.baseURL,
            apiService: apiService,
            buildRequestBody: { model in
                try adapter.buildRequestBody(
                    messages: [ChatMessage(role: .user, content: "ping")],
                    model: model,
                    tools: nil,
                    systemPrompt: ""
                )
            },
            buildRequest: buildRequest,
            resolveAPIKey: resolveAPIKey
        )
    }
}

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
            return .unavailable( LumiLLMFailureDetailResolver.resolve(from: error))
        }

        guard let url = URL(string: baseURL) else {
            return .unavailable( .message("无效的 Base URL"))
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
            return .unavailable( detail)
        }
    }
}

public extension OpenAICompatibleLumiProvider {
    func checkAvailabilityUsingChatPing(model: String) async -> LumiModelAvailabilityResult {
        await LumiOpenAICompatibleAvailability.chatPing(
            model: model,
            adapter: lumiOpenAIAdapter,
            apiService: lumiAPIService,
            buildRequest: buildRequest(url:apiKey:),
            resolveAPIKey: lumiResolveAPIKey
        )
    }
}

public extension AnthropicCompatibleLumiProvider {
    func checkAvailabilityUsingChatPing(model: String) async -> LumiModelAvailabilityResult {
        await LumiAnthropicCompatibleAvailability.chatPing(
            model: model,
            adapter: lumiAnthropicAdapter,
            apiService: lumiAPIService,
            buildRequest: buildRequest(url:apiKey:),
            resolveAPIKey: lumiResolveAPIKey
        )
    }
}
