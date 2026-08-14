import Foundation
import KernelLumi
import LLMKit

public final class OpenCodeGoProvider: LumiLLMProvider, @unchecked Sendable {
    private enum Kind { case responses, openAI, anthropic }
    private struct Model { let id: String; let name: String; let kind: Kind }
    private static let base = "https://opencode.ai/zen/go/v1"
    private static let models: [Model] = [
        .init(id: "grok-4.5", name: "Grok 4.5", kind: .responses),
        .init(id: "gpt-5.6-luna", name: "GPT 5.6 Luna", kind: .responses),
        .init(id: "glm-5.3", name: "GLM-5.3", kind: .openAI),
            .init(id: "glm-5.2", name: "GLM-5.2", kind: .openAI),
            .init(id: "glm-5.1", name: "GLM-5.1", kind: .openAI),
        .init(id: "kimi-k3", name: "Kimi K3", kind: .openAI),
            .init(id: "kimi-k2.7-code", name: "Kimi K2.7 Code", kind: .openAI),
            .init(id: "kimi-k2.6", name: "Kimi K2.6", kind: .openAI),
        .init(id: "mimo-v2.5", name: "MiMo-V2.5", kind: .openAI),
            .init(id: "mimo-v2.5-pro", name: "MiMo-V2.5-Pro", kind: .openAI),
        .init(id: "deepseek-v4-pro", name: "DeepSeek V4 Pro", kind: .openAI), .init(id: "deepseek-v4-flash", name: "DeepSeek V4 Flash", kind: .openAI), .init(id: "hy3", name: "Hy3", kind: .openAI),
        .init(id: "minimax-m3", name: "MiniMax M3", kind: .anthropic), .init(id: "minimax-m2.7", name: "MiniMax M2.7", kind: .anthropic), .init(id: "minimax-m2.5", name: "MiniMax M2.5", kind: .anthropic),
        .init(id: "qwen3.8-max", name: "Qwen3.8 Max", kind: .anthropic), .init(id: "qwen3.7-max", name: "Qwen3.7 Max", kind: .anthropic), .init(id: "qwen3.7-plus", name: "Qwen3.7 Plus", kind: .anthropic), .init(id: "qwen3.6-plus", name: "Qwen3.6 Plus", kind: .anthropic),
    ]
    public static let info = LumiLLMProviderInfo(id: "opencode-go", displayName: "OpenCode Go", description: "低成本的开源编程模型订阅服务", defaultModel: "deepseek-v4-flash", availableModels: models.map { LumiModelInfo(id: $0.id, displayName: $0.name, capabilities: .init(supportsVision: false, supportsTools: true)) }, websiteURL: URL(string: "https://opencode.ai/docs/zh-cn/go/")!, apiKeyStorageKey: "DevAssistant_ApiKey_OpenCodeGo")
    public var providerInfo: LumiLLMProviderInfo { Self.info }
    private let api = LLMAPIService()
    private var keyName: String { Self.info._apiKeyStorageKey! }
    public init() {}
    public func lumiResolveAPIKey() throws -> String { try LumiAPIKeyTools.resolve(storageKey: keyName, displayName: Self.info.displayName) }
    public func hasApiKey() -> Bool { LumiAPIKeyTools.has(storageKey: keyName) }
    public func getApiKey() -> String { LumiAPIKeyTools.get(storageKey: keyName) }
    public func setApiKey(_ value: String) { LumiAPIKeyTools.set(value, storageKey: keyName) }
    public func removeApiKey() { LumiAPIKeyTools.remove(storageKey: keyName) }
    public func checkAvailability(model: String) async -> LumiModelAvailabilityResult { hasApiKey() ? .available : .unavailable(.message("未配置 API Key")) }
    public func providerStatus() -> LumiLLMProviderStatus? { hasApiKey() ? nil : LumiLLMProviderStatusSupport.missingAPIKeyStatus(providerName: Self.info.displayName) }
    public func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition { .retryable() }
    public func errorRenderKind(for error: Error) -> String? { nil }
    public func makeErrorMessage(conversationID: UUID, request: LumiLLMRequest, error: Error, disposition: LumiLLMErrorDisposition) -> LumiChatMessage { LumiLLMProviderErrorSupport.makeErrorMessage(providerID: Self.info.id, conversationID: conversationID, request: request, error: error, disposition: disposition, renderKind: nil) }
    public func sendStreaming(_ request: LumiLLMRequest, onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void) async throws -> LumiChatMessage { let m = try await send(request); if !m.content.isEmpty { await onChunk(.init(content: m.content, isDone: false)) }; await onChunk(.init(content: nil, isDone: true)); return m }

    public func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        guard let model = Self.models.first(where: { $0.id == request.model }) else { throw LumiLLMProviderSupportError.emptyResponse }
        switch model.kind { case .openAI: return try await chat(request, anthropic: false); case .anthropic: return try await chat(request, anthropic: true); case .responses: return try await responses(request) }
    }

    private func url(_ path: String) throws -> URL { guard let u = URL(string: "\(Self.base)/\(path)") else { throw LumiLLMProviderSupportError.invalidBaseURL(Self.base) }; return u }
    private func message(_ r: LumiLLMRequest, _ text: String, _ calls: [LumiToolCall]? = nil) -> LumiChatMessage { .init(conversationID: r.messages.first?.conversationID ?? UUID(), role: .assistant, content: text, providerID: Self.info.id, modelName: r.model, toolCalls: calls) }
    private func chat(_ r: LumiLLMRequest, anthropic: Bool) async throws -> LumiChatMessage {
        let ms = LumiLLMRequestMessages.preparedForProvider(r); let tools = r.tools.map(LumiToolSchema.init)
        if anthropic { let a = AnthropicCompatibleProviderAdapter(configuration: .init(baseURL: Self.base)); let body = try a.buildRequestBody(messages: ms, model: r.model, tools: tools, systemPrompt: ""); let data = try await api.sendChatRequest(request: a.buildRequest(url: try url("messages"), apiKey: try lumiResolveAPIKey()), body: body); let p = try a.parseResponse(data: data); return message(r, p.content, p.toolCalls?.map { .init(id: $0.id, name: $0.name, arguments: $0.arguments) }) }
        let a = OpenAICompatibleProviderAdapter(configuration: .init(baseURL: Self.base)); let body = try a.buildRequestBody(messages: ms, model: r.model, tools: tools, systemPrompt: ""); let data = try await api.sendChatRequest(request: a.buildRequest(url: try url("chat/completions"), apiKey: try lumiResolveAPIKey()), body: body); let p = try a.parseResponse(data: data); return message(r, p.content, p.toolCalls?.map { .init(id: $0.id, name: $0.name, arguments: $0.arguments) })
    }

    private func responses(_ r: LumiLLMRequest) async throws -> LumiChatMessage {
        let input = LumiLLMRequestMessages.preparedForProvider(r).map { ["role": $0.role.rawValue, "content": $0.content] as [String: Any] }; var body: [String: Any] = ["model": r.model, "input": input]
        if !r.tools.isEmpty { body["tools"] = r.tools.map { ["type": "function", "name": $0.name, "description": $0.toolDescription, "parameters": $0.inputSchema.anyValue] }
        }
        var req = URLRequest(url: try url("responses")); req.httpMethod = "POST"; req.setValue("Bearer \(try lumiResolveAPIKey())", forHTTPHeaderField: "Authorization"); req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let object = try JSONSerialization.jsonObject(with: try await api.sendChatRequest(request: req, body: body)) as? [String: Any] ?? [:]; let output = object["output"] as? [[String: Any]] ?? []; let text = (object["output_text"] as? String) ?? output.flatMap { ($0["content"] as? [[String: Any]]) ?? [] }.compactMap { $0["text"] as? String }.joined(); let calls = output.filter { $0["type"] as? String == "function_call" }.compactMap { x -> LumiToolCall? in guard let id = x["call_id"] as? String ?? x["id"] as? String, let n = x["name"] as? String else { return nil }; return .init(id: id, name: n, arguments: x["arguments"] as? String ?? "{}") }; return message(r, text, calls.isEmpty ? nil : calls)
    }
}
