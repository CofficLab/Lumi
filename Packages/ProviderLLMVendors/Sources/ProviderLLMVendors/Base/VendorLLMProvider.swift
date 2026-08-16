import Foundation
import ProviderLLM
import ProviderLLMManager
import ProviderMessage

/// 新版内建 LLM 供应商基类（KernelCore 生态，不依赖 KernelLumi）。
///
/// 每个供应商子类只需提供：
/// - `providerInfo`（模型列表、协议格式、API Key storage key 等元数据）；
/// - 对应协议的 adapter 配置（`openAIConfiguration` / `anthropicConfiguration`）。
///
/// 发送路径统一走非流式 JSON（`complete(_:)`），按 `apiFormat` 路由到
/// OpenAI / Anthropic / Responses 三套 adapter，复用 LLMKit 的请求构建与
/// 响应解析（避免 22 个旧插件各自复制网络解析逻辑）。
@MainActor
open class VendorLLMProvider: ManagedLLMProvider, @preconcurrency LLMProviding {

    public let providerInfo: LLMProviderInfo
    public let apiService: VendorAPIService

    /// OpenAI 兼容协议适配器配置（子类覆盖）。
    open var openAIConfiguration: OpenAICompatibleProviderConfiguration? { nil }

    /// Anthropic 兼容协议适配器配置（子类覆盖）。
    open var anthropicConfiguration: AnthropicCompatibleProviderConfiguration? { nil }

    public init(
        info: LLMProviderInfo,
        apiService: VendorAPIService = VendorAPIService()
    ) {
        self.providerInfo = info
        self.apiService = apiService
    }

    public var providerID: String { providerInfo.id }

    // MARK: - LLMProviding

    open func complete(_ request: LLMRequest) async throws -> LLMResponse {
        switch providerInfo.apiFormat {
        case .openAI:
            return try await sendOpenAI(request)
        case .anthropic:
            return try await sendAnthropic(request)
        case .responses:
            return try await sendResponses(request)
        }
    }

    // MARK: - API Key

    public func hasApiKey() -> Bool {
        VendorAPIKeyTools.has(storageKey: providerInfo.apiKeyStorageKey)
    }

    public func getApiKey() -> String {
        VendorAPIKeyTools.get(storageKey: providerInfo.apiKeyStorageKey)
    }

    public func setApiKey(_ apiKey: String) {
        VendorAPIKeyTools.set(apiKey, storageKey: providerInfo.apiKeyStorageKey)
    }

    public func removeApiKey() {
        VendorAPIKeyTools.remove(storageKey: providerInfo.apiKeyStorageKey)
    }

    public func resolveAPIKey() throws -> String {
        try VendorAPIKeyTools.resolve(
            storageKey: providerInfo.apiKeyStorageKey,
            displayName: providerInfo.displayName
        )
    }

    // MARK: - OpenAI

    private func sendOpenAI(_ request: LLMRequest) async throws -> LLMResponse {
        guard let configuration = openAIConfiguration else {
            throw VendorAPIError.requestFailed("\(providerInfo.displayName) 未配置 OpenAI 端点")
        }
        let adapter = OpenAICompatibleProviderAdapter(configuration: configuration)
        let body = try adapter.buildRequestBody(
            messages: VendorMessageBridging.chatMessages(from: request.messages),
            model: request.model ?? providerInfo.defaultModel,
            tools: nil,
            systemPrompt: ""
        )
        let data = try await apiService.sendChatRequest(
            request: adapter.buildRequest(url: try endpointURL(configuration.baseURL), apiKey: try resolveAPIKey()),
            body: body
        )
        let parsed = try adapter.parseResponse(data: data)
        return LLMResponse(content: parsed.content, model: request.model ?? providerInfo.defaultModel)
    }

    // MARK: - Anthropic

    private func sendAnthropic(_ request: LLMRequest) async throws -> LLMResponse {
        guard let configuration = anthropicConfiguration else {
            throw VendorAPIError.requestFailed("\(providerInfo.displayName) 未配置 Anthropic 端点")
        }
        let adapter = AnthropicCompatibleProviderAdapter(configuration: configuration)
        let body = try adapter.buildRequestBody(
            messages: VendorMessageBridging.chatMessages(from: request.messages),
            model: request.model ?? providerInfo.defaultModel,
            tools: nil,
            systemPrompt: ""
        )
        let data = try await apiService.sendChatRequest(
            request: adapter.buildRequest(url: try endpointURL(configuration.baseURL), apiKey: try resolveAPIKey()),
            body: body
        )
        let parsed = try adapter.parseResponse(data: data)
        return LLMResponse(content: parsed.content, model: request.model ?? providerInfo.defaultModel)
    }

    // MARK: - Responses（OpenAI Responses 协议）

    private func sendResponses(_ request: LLMRequest) async throws -> LLMResponse {
        let model = request.model ?? providerInfo.defaultModel
        var input: [[String: Any]] = []
        for message in VendorMessageBridging.chatMessages(from: request.messages) {
            input.append(["role": message.role.rawValue, "content": message.content])
        }
        let body: [String: Any] = ["model": model, "input": input]

        var httpRequest = URLRequest(url: try endpointURL(responsesEndpointURL))
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("Bearer \(try resolveAPIKey())", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let data = try await apiService.sendJSON(request: httpRequest, body: body)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let text = Self.responsesText(from: object)
        return LLMResponse(content: text, model: model)
    }

    /// Responses 协议端点；默认 OpenAI 官方，子类可覆盖。
    open var responsesEndpointURL: String { "https://api.openai.com/v1/responses" }

    // MARK: - Helpers

    private func endpointURL(_ string: String) throws -> URL {
        guard let url = URL(string: string) else {
            throw VendorAPIError.invalidBaseURL(string)
        }
        return url
    }

    private static func responsesText(from object: [String: Any]) -> String {
        if let text = object["output_text"] as? String { return text }
        guard let output = object["output"] as? [[String: Any]] else { return "" }
        return output
            .flatMap { ($0["content"] as? [[String: Any]]) ?? [] }
            .compactMap { $0["text"] as? String }
            .joined()
    }
}
