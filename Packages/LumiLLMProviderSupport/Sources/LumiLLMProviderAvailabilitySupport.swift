import Foundation
import HttpKit
import LLMKit
import LLMProviderKit
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
            return .unavailable(reason: LumiLLMProviderSupportLocalization.userFacingDescription(for: error))
        }

        guard let url = URL(string: baseURL) else {
            return .unavailable(reason: "无效的 Base URL")
        }

        let body: [String: Any]
        do {
            body = try buildRequestBody(model)
        } catch {
            return .unavailable(reason: error.localizedDescription)
        }

        let httpRequest = buildRequest(url, apiKeyValue)

        do {
            _ = try await apiService.sendChatRequest(
                request: httpRequest,
                body: body
            )
            return .available
        } catch {
            return .unavailable(
                reason: LumiLLMProviderSupportLocalization.userFacingDescription(for: error)
            )
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
