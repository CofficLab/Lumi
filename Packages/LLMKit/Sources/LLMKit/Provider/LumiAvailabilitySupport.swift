import Foundation
import HttpKit
import LLMKit
import LumiCoreMessage

/// OpenAI 兼容供应商可用性检查工具
public enum LumiOpenAICompatibleAvailability {
    public static func chatPing(
        model: String,
        adapter: OpenAICompatibleProviderAdapter,
        apiService: LLMAPIService,
        buildRequest: (URL, String) -> URLRequest,
        resolveAPIKey: () throws -> String
    ) async -> LumiModelAvailabilityResult {
        // Simple ping implementation
        do {
            let apiKey = try resolveAPIKey()
            guard let url = URL(string: adapter.configuration.baseURL) else {
                return .unavailable(.message("Invalid base URL"))
            }
            let request = buildRequest(url, apiKey)
            let body = try adapter.buildRequestBody(
                messages: [ChatMessage(role: .user, content: "ping")],
                model: model,
                tools: nil,
                systemPrompt: ""
            )

            var hasError: Error?
            try await apiService.sendStreamingRequest(
                request: request,
                body: body,
                onResponseReceived: { _ in },
                onChunk: { _ in true }
            )

            if hasError != nil {
                return .unavailable(.message(hasError?.localizedDescription ?? "Unknown error"))
            }
            return .available
        } catch {
            return .unavailable(.message(error.localizedDescription))
        }
    }
}

/// Anthropic 兼容供应商可用性检查工具
public enum LumiAnthropicCompatibleAvailability {
    public static func chatPing(
        model: String,
        adapter: AnthropicCompatibleProviderAdapter,
        apiService: LLMAPIService,
        buildRequest: (URL, String) -> URLRequest,
        resolveAPIKey: () throws -> String
    ) async -> LumiModelAvailabilityResult {
        do {
            let apiKey = try resolveAPIKey()
            guard let url = URL(string: adapter.configuration.baseURL) else {
                return .unavailable(.message("Invalid base URL"))
            }
            let request = buildRequest(url, apiKey)
            let body = try adapter.buildRequestBody(
                messages: [ChatMessage(role: .user, content: "ping")],
                model: model,
                tools: nil,
                systemPrompt: ""
            )

            try await apiService.sendStreamingRequest(
                request: request,
                body: body,
                onResponseReceived: { _ in },
                onChunk: { _ in true }
            )

            return .available
        } catch {
            return .unavailable(.message(error.localizedDescription))
        }
    }
}

