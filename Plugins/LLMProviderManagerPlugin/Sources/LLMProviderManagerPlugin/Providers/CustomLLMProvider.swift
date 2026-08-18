import Foundation
import HttpKit
import KernelLumi
import LLMKit

final class CustomLLMProvider: LumiLLMProvider, @unchecked Sendable {
    static let info = LumiLLMProviderInfo(
        id: "custom-placeholder",
        displayName: "Custom Provider",
        defaultModel: "",
        availableModels: [LumiModelInfo](),
        websiteURL: URL(string: "https://example.invalid")!
    )

    let configuration: CustomProviderConfiguration
    let providerInfo: LumiLLMProviderInfo
    private let apiService: LLMAPIService

    init(configuration: CustomProviderConfiguration, network: (any NetworkProviding)? = nil) {
        self.configuration = configuration
        self.providerInfo = configuration.info
        if let network {
            self.apiService = LLMAPIService(network: network)
        } else {
            self.apiService = LLMAPIService()
        }
    }

    func lumiResolveAPIKey() throws -> String {
        try LumiAPIKeyTools.resolve(storageKey: configuration.apiKeyStorageKey, displayName: providerInfo.displayName)
    }

    func hasApiKey() -> Bool { LumiAPIKeyTools.has(storageKey: configuration.apiKeyStorageKey) }
    func getApiKey() -> String { LumiAPIKeyTools.get(storageKey: configuration.apiKeyStorageKey) }
    func setApiKey(_ apiKey: String) { LumiAPIKeyTools.set(apiKey, storageKey: configuration.apiKeyStorageKey) }
    func removeApiKey() { LumiAPIKeyTools.remove(storageKey: configuration.apiKeyStorageKey) }

    func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        let message: LumiChatMessage
        switch configuration.protocolType {
        case .openAI: message = try await sendOpenAI(request)
        case .anthropic: message = try await sendAnthropic(request)
        case .responses: message = try await sendResponses(request)
        }
        return message
    }

    func sendStreaming(_ request: LumiLLMRequest, onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void) async throws -> LumiChatMessage {
        // The first version deliberately uses the reliable JSON path for all
        // custom endpoints. It still reports a final chunk and keeps the
        // provider contract identical while endpoint-specific SSE quirks vary.
        let message = try await send(request)
        if !message.content.isEmpty {
            await onChunk(LumiStreamChunk(content: message.content, isDone: false))
        }
        await onChunk(LumiStreamChunk(content: nil, isDone: true))
        return message
    }

    func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        guard hasApiKey() else { return .unavailable(.message("未配置 API Key")) }
        return .available
    }

    func providerStatus() -> LumiLLMProviderStatus? {
        hasApiKey() ? nil : LumiLLMProviderStatusSupport.missingAPIKeyStatus(providerName: providerInfo.displayName)
    }

    func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        .retryable()
    }

    func errorRenderKind(for error: Error) -> String? { nil }

    func makeErrorMessage(conversationID: UUID, request: LumiLLMRequest, error: Error, disposition: LumiLLMErrorDisposition) -> LumiChatMessage {
        LumiLLMProviderErrorSupport.makeErrorMessage(
            providerID: providerInfo.id,
            conversationID: conversationID,
            request: request,
            error: error,
            disposition: disposition,
            renderKind: nil
        )
    }

    private func sendOpenAI(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        let adapter = OpenAICompatibleProviderAdapter(configuration: .init(baseURL: configuration.baseURL))
        let body = try adapter.buildRequestBody(
            messages: LumiLLMRequestMessages.preparedForProvider(request),
            model: request.model,
            tools: request.tools.map(LumiToolSchema.init),
            systemPrompt: ""
        )
        let data = try await apiService.sendChatRequest(request: adapter.buildRequest(url: try endpointURL(), apiKey: lumiResolveAPIKey()), body: body)
        let parsed = try adapter.parseResponse(data: data)
        return makeMessage(request, content: parsed.content, toolCalls: parsed.toolCalls?.map { LumiToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) })
    }

    private func sendAnthropic(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        let adapter = AnthropicCompatibleProviderAdapter(configuration: .init(baseURL: configuration.baseURL))
        let body = try adapter.buildRequestBody(
            messages: LumiLLMRequestMessages.preparedForProvider(request),
            model: request.model,
            tools: request.tools.map(LumiToolSchema.init),
            systemPrompt: ""
        )
        let data = try await apiService.sendChatRequest(request: adapter.buildRequest(url: try endpointURL(), apiKey: lumiResolveAPIKey()), body: body)
        let parsed = try adapter.parseResponse(data: data)
        return makeMessage(request, content: parsed.content, toolCalls: parsed.toolCalls?.map { LumiToolCall(id: $0.id, name: $0.name, arguments: $0.arguments) })
    }

    private func sendResponses(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        var input: [[String: Any]] = []
        for message in LumiLLMRequestMessages.preparedForProvider(request) {
            input.append(["role": message.role.rawValue, "content": message.content])
        }
        var body: [String: Any] = ["model": request.model, "input": input]
        if !request.tools.isEmpty {
            body["tools"] = request.tools.map { tool in
                ["type": "function", "name": tool.name, "description": tool.toolDescription, "parameters": tool.inputSchema.anyValue]
            }
        }
        let url = try endpointURL()
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("Bearer \(try lumiResolveAPIKey())", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let data = try await apiService.sendChatRequest(request: httpRequest, body: body)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let content = Self.responsesText(from: object)
        let calls = Self.responsesToolCalls(from: object)
        return makeMessage(request, content: content, toolCalls: calls)
    }

    private func endpointURL() throws -> URL {
        guard let url = URL(string: configuration.baseURL) else { throw LumiLLMProviderSupportError.invalidBaseURL(configuration.baseURL) }
        return url
    }

    private func makeMessage(_ request: LumiLLMRequest, content: String, toolCalls: [LumiToolCall]? = nil) -> LumiChatMessage {
        LumiChatMessage(conversationID: request.messages.first?.conversationID ?? UUID(), role: .assistant, content: content, providerID: providerInfo.id, modelName: request.model, toolCalls: toolCalls)
    }

    private static func responsesText(from object: [String: Any]) -> String {
        if let text = object["output_text"] as? String { return text }
        guard let output = object["output"] as? [[String: Any]] else { return "" }
        return output.flatMap { ($0["content"] as? [[String: Any]]) ?? [] }.compactMap { $0["text"] as? String }.joined()
    }

    private static func responsesToolCalls(from object: [String: Any]) -> [LumiToolCall]? {
        guard let output = object["output"] as? [[String: Any]] else { return nil }
        let calls = output.filter { ($0["type"] as? String) == "function_call" }.compactMap { item -> LumiToolCall? in
            guard let id = item["call_id"] as? String ?? item["id"] as? String,
                  let name = item["name"] as? String else { return nil }
            return LumiToolCall(id: id, name: name, arguments: item["arguments"] as? String ?? "{}")
        }
        return calls.isEmpty ? nil : calls
    }
}
