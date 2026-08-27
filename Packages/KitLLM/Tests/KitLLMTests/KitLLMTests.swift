import Foundation
import Testing
@testable import KitLLM

@MainActor
struct KitLLMTests {

    @Test("LLMMessage 构造和字段访问")
    func messageCreation() {
        let msg = LLMMessage(role: .user, content: "hello")
        #expect(msg.role == .user)
        #expect(msg.content == "hello")
        #expect(msg.toolCalls == nil)
        #expect(msg.images.isEmpty)
    }

    @Test("LLMRequest 构造")
    func requestCreation() {
        let request = LLMRequest(
            messages: [LLMMessage(role: .user, content: "test")],
            model: "gpt-4"
        )
        #expect(request.messages.count == 1)
        #expect(request.model == "gpt-4")
        #expect(request.tools == nil)
    }

    @Test("LLMProviderInfo 元数据")
    func providerInfo() {
        let info = LLMProviderInfo(
            id: "test",
            displayName: "Test Provider",
            description: "A test provider",
            defaultModel: "test-model",
            models: [
                LLMModelInfo(id: "test-model", contextWindowSize: 100_000, supportsVision: true),
            ],
            apiFormat: .openAI,
            apiKeyStorageKey: "test-key"
        )
        #expect(info.id == "test")
        #expect(info.contains(model: "test-model"))
        #expect(!info.contains(model: "nonexistent"))
        #expect(info.modelIDs == ["test-model"])
    }

    @Test("VendorAPIError 错误描述")
    func errorDescriptions() {
        let missing = VendorAPIError.missingAPIKey("TestProvider")
        #expect(missing.errorDescription?.contains("TestProvider") == true)

        let http = VendorAPIError.httpStatus(401, "Unauthorized")
        #expect(http.errorDescription?.contains("401") == true)
    }

    @Test("LLMToolNameSanitizer 转义规则")
    func toolNameSanitizer() {
        // 合法名不变
        #expect(LLMToolNameSanitizer.sanitize("read_file") == "read_file")
        // 点号转下划线
        #expect(LLMToolNameSanitizer.sanitize("app-store-connect.list-apps") == "app-store-connect_list-apps")
        // round-trip
        let original = "my.tool.name"
        let sanitized = LLMToolNameSanitizer.sanitize(original)
        #expect(!sanitized.contains("."))
    }

    @Test("OpenAI adapter 构建请求体")
    func openAIAdapterBuildsBody() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(baseURL: "https://api.openai.com/v1")
        )
        let messages = [LLMMessage(role: .user, content: "hello")]
        let body = try adapter.buildRequestBody(messages: messages, model: "gpt-4", tools: nil, systemPrompt: "")

        #expect(body["model"] as? String == "gpt-4")
        let bodyMessages = body["messages"] as? [[String: Any]]
        #expect(bodyMessages?.count == 1)
    }

    @Test("Anthropic adapter 构建请求体")
    func anthropicAdapterBuildsBody() throws {
        let adapter = AnthropicCompatibleProviderAdapter(
            configuration: AnthropicCompatibleProviderConfiguration(baseURL: "https://api.anthropic.com")
        )
        let messages = [LLMMessage(role: .user, content: "hello")]
        let body = try adapter.buildRequestBody(messages: messages, model: "claude-3", tools: nil, systemPrompt: "You are helpful")

        #expect(body["model"] as? String == "claude-3")
        #expect(body["system"] as? String == "You are helpful")
    }

    @Test("VendorAPIKeyTools set/get/remove")
    func apiKeyTools() {
        VendorAPIKeyTools.keychainService = "com.kit.llm.test.\(UUID().uuidString)"
        defer { VendorAPIKeyTools.remove(storageKey: "test-key") }

        #expect(!VendorAPIKeyTools.has(storageKey: "test-key"))
        VendorAPIKeyTools.set("sk-test-123", storageKey: "test-key")
        #expect(VendorAPIKeyTools.has(storageKey: "test-key"))
        #expect(VendorAPIKeyTools.get(storageKey: "test-key") == "sk-test-123")
        VendorAPIKeyTools.remove(storageKey: "test-key")
        #expect(!VendorAPIKeyTools.has(storageKey: "test-key"))
    }

    @Test("网络中断可重试但认证失败不可重试")
    func retryPolicyClassifiesTransientErrors() {
        let network = ProviderRetryPolicy.decision(
            forNetworkError: NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost),
            attempt: 1,
            maxAttempts: 3
        )
        #expect(network.shouldRetry)

        let unauthorized = ProviderRetryPolicy.decision(
            statusCode: 401,
            retryAfter: nil,
            attempt: 1,
            maxAttempts: 3
        )
        #expect(!unauthorized.shouldRetry)
    }
}
