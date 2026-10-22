import Foundation
import Testing
@testable import KitLLM

// MARK: - 测试替身

/// 可编程的网络替身：返回预设响应 / SSE 事件，并记录收到的请求。
private final class FakeNetworkProvider: LLMNetworkProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var storedResponse = Data()
    private var storedStatusCode = 200
    private var storedStreamEvents: [Data] = []
    private var storedRequests: [URLRequest] = []
    private var storedBodies: [Data] = []
    private var storedError: Error?

    func setResponse(data: Data, statusCode: Int = 200) {
        lock.withLock {
            storedResponse = data
            storedStatusCode = statusCode
        }
    }

    func setStreamEvents(_ events: [Data]) {
        lock.withLock { storedStreamEvents = events }
    }

    func setError(_ error: Error?) {
        lock.withLock { storedError = error }
    }

    var requests: [URLRequest] { lock.withLock { storedRequests } }

    var bodies: [Data] { lock.withLock { storedBodies } }

    /// 最近一次请求体解析出的 JSON 对象。
    var lastBodyJSON: [String: Any] {
        guard let body = bodies.last,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return [:]
        }
        return object
    }

    func send(request: URLRequest, body: Data) async throws -> (Data, URLResponse) {
        let (data, statusCode, error) = lock.withLock { () -> (Data, Int, Error?) in
            storedRequests.append(request)
            storedBodies.append(body)
            return (storedResponse, storedStatusCode, storedError)
        }
        if let error { throw error }
        let url = request.url ?? URL(string: "https://example.invalid")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        return (data, response)
    }

    func stream(
        request: URLRequest,
        body: Data,
        onEvent: @Sendable @escaping (Data) async -> Bool
    ) async throws {
        let (events, error) = lock.withLock { () -> ([Data], Error?) in
            storedRequests.append(request)
            storedBodies.append(body)
            return (storedStreamEvents, storedError)
        }
        if let error { throw error }
        for event in events {
            if !(await onEvent(event)) { return }
        }
    }
}

/// 不触碰 Keychain 的测试供应商。
@MainActor
private final class TestVendorProvider: VendorLLMProvider {
    private let openAI: OpenAICompatibleProviderConfiguration?
    private let anthropic: AnthropicCompatibleProviderConfiguration?

    init(
        info: LLMProviderInfo,
        apiService: VendorAPIService,
        openAI: OpenAICompatibleProviderConfiguration? = nil,
        anthropic: AnthropicCompatibleProviderConfiguration? = nil
    ) {
        self.openAI = openAI
        self.anthropic = anthropic
        super.init(info: info, apiService: apiService)
    }

    override var openAIConfiguration: OpenAICompatibleProviderConfiguration? { openAI }
    override var anthropicConfiguration: AnthropicCompatibleProviderConfiguration? { anthropic }

    // 测试不访问 Keychain，直接给固定 Key。
    override func hasApiKey() -> Bool { true }
    override func getApiKey() -> String { "test-key" }
    override func resolveAPIKey() throws -> String { "test-key" }
    override func setApiKey(_ apiKey: String) {}
    override func removeApiKey() {}
}

/// 线程安全的流式 chunk 收集器。
private final class ChunkCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [LLMStreamChunk] = []

    func append(_ chunk: LLMStreamChunk) {
        lock.withLock { stored.append(chunk) }
    }

    var chunks: [LLMStreamChunk] { lock.withLock { stored } }

    var text: String {
        chunks.compactMap(\.content).joined()
    }

    var reasoningText: String {
        chunks.compactMap(\.reasoningContent).joined()
    }
}

// MARK: - 夹具

private enum Fixture {
    static func openAIConfig() -> OpenAICompatibleProviderConfiguration {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.example.com/v1/chat/completions",
            additionalHeaders: ["X-Provider": "test"]
        )
    }

    static func anthropicConfig() -> AnthropicCompatibleProviderConfiguration {
        AnthropicCompatibleProviderConfiguration(
            baseURL: "https://api.example.com/v1/messages",
            defaultMaxTokens: 4096
        )
    }

    static func providerInfo(
        id: String = "test",
        format: LLMProviderAPIFormat,
        defaultModel: String = "default-model"
    ) -> LLMProviderInfo {
        LLMProviderInfo(
            id: id,
            displayName: "Test Provider",
            defaultModel: defaultModel,
            models: [LLMModelInfo(id: defaultModel)],
            apiFormat: format,
            apiKeyStorageKey: "test-key"
        )
    }

    /// 组装一条 OpenAI 兼容的 SSE 事件。
    static func sse(_ payload: [String: Any]) -> Data {
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let json = String(decoding: data, as: UTF8.self)
        return Data("data: \(json)\n\n".utf8)
    }

    /// 组装一条 Anthropic 兼容的 SSE 事件。
    static func anthropicSSE(event: String, payload: [String: Any]) -> Data {
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let json = String(decoding: data, as: UTF8.self)
        return Data("event: \(event)\ndata: \(json)\n\n".utf8)
    }
}

// MARK: - 非流式请求

@Suite("VendorLLMProvider 非流式请求")
@MainActor
struct VendorProviderCompletionTests {

    private func makeProvider(
        network: FakeNetworkProvider,
        format: LLMProviderAPIFormat,
        id: String = "test",
        defaultModel: String = "default-model"
    ) -> TestVendorProvider {
        let service = VendorAPIService(networkProvider: network, maxAttempts: 1, baseRetryDelay: 0)
        let info = Fixture.providerInfo(id: id, format: format, defaultModel: defaultModel)
        return TestVendorProvider(
            info: info,
            apiService: service,
            openAI: format == .openAI ? Fixture.openAIConfig() : nil,
            anthropic: format == .anthropic ? Fixture.anthropicConfig() : nil
        )
    }

    @Test("OpenAI 兼容协议返回正文与 token 统计")
    func openAICompletionParsesResponse() async throws {
        let network = FakeNetworkProvider()
        network.setResponse(data: Data(#"""
        {"choices":[{"message":{"content":"hello"}}],"usage":{"prompt_tokens":11,"completion_tokens":7}}
        """#.utf8))
        let provider = makeProvider(network: network, format: .openAI)
        let request = LLMRequest(
            messages: [LLMMessage(role: .user, content: "hi")],
            model: "gpt-4o"
        )

        let response = try await provider.complete(request)

        #expect(response.content == "hello")
        #expect(response.model == "gpt-4o")
        #expect(response.inputTokenCount == 11)
        #expect(response.outputTokenCount == 7)

        let sent = try #require(network.requests.first)
        #expect(sent.httpMethod == "POST")
        #expect(sent.url?.absoluteString == "https://api.example.com/v1/chat/completions")
        #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
        #expect(sent.value(forHTTPHeaderField: "X-Provider") == "test")
        #expect(network.lastBodyJSON["model"] as? String == "gpt-4o")
        #expect(network.lastBodyJSON["stream"] as? Bool == false)
    }

    @Test("未指定模型时回落到供应商默认模型")
    func fallsBackToDefaultModel() async throws {
        let network = FakeNetworkProvider()
        network.setResponse(data: Data(#"{"choices":[{"message":{"content":"ok"}}]}"#.utf8))
        let provider = makeProvider(network: network, format: .openAI, defaultModel: "fallback-model")
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "hi")])

        let response = try await provider.complete(request)

        #expect(response.model == "fallback-model")
        #expect(network.lastBodyJSON["model"] as? String == "fallback-model")
    }

    @Test("工具名被转义并在响应中还原")
    func toolNamesAreSanitizedAndRestored() async throws {
        let network = FakeNetworkProvider()
        network.setResponse(data: Data(#"""
        {"choices":[{"message":{"content":"","tool_calls":[{"id":"call-1","type":"function","function":{"name":"app_read","arguments":"{}"}}]}}]}
        """#.utf8))
        let provider = makeProvider(network: network, format: .openAI)
        let request = LLMRequest(
            messages: [LLMMessage(role: .user, content: "hi")],
            tools: [LLMFunctionSchema(name: "app.read", description: "读取", parameters: [:])]
        )

        let response = try await provider.complete(request)

        let tools = try #require(network.lastBodyJSON["tools"] as? [[String: Any]])
        let function = try #require(tools.first?["function"] as? [String: Any])
        #expect(function["name"] as? String == "app_read")
        #expect(response.toolCalls?.first?.name == "app.read")
        #expect(response.toolCalls?.first?.id == "call-1")
    }

    @Test("Anthropic 兼容协议返回正文与 token 统计")
    func anthropicCompletionParsesResponse() async throws {
        let network = FakeNetworkProvider()
        network.setResponse(data: Data(#"""
        {"content":[{"type":"text","text":"hello"}],"usage":{"input_tokens":13,"output_tokens":5}}
        """#.utf8))
        let provider = makeProvider(network: network, format: .anthropic)
        let request = LLMRequest(
            messages: [LLMMessage(role: .user, content: "hi")],
            model: "claude-sonnet-4"
        )

        let response = try await provider.complete(request)

        #expect(response.content == "hello")
        #expect(response.model == "claude-sonnet-4")
        #expect(response.inputTokenCount == 13)
        #expect(response.outputTokenCount == 5)

        let sent = try #require(network.requests.first)
        #expect(sent.url?.absoluteString == "https://api.example.com/v1/messages")
        #expect(sent.value(forHTTPHeaderField: "x-api-key") == "test-key")
        #expect(sent.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(network.lastBodyJSON["max_tokens"] as? Int == 4096)
    }

    @Test("多条 system 消息被合并进顶层 system 字段")
    func mergesSystemMessages() async throws {
        let network = FakeNetworkProvider()
        network.setResponse(data: Data(#"{"content":[{"type":"text","text":"ok"}]}"#.utf8))
        let provider = makeProvider(network: network, format: .anthropic)
        let request = LLMRequest(
            messages: [
                LLMMessage(role: .system, content: "第一段"),
                LLMMessage(role: .system, content: "第二段"),
                LLMMessage(role: .user, content: "hi"),
            ]
        )

        _ = try await provider.complete(request)

        #expect(network.lastBodyJSON["system"] as? String == "第一段\n\n第二段")
    }

    @Test("Responses 协议读取 output_text")
    func responsesProtocolReadsOutputText() async throws {
        let network = FakeNetworkProvider()
        network.setResponse(data: Data(#"{"output_text":"responses reply"}"#.utf8))
        let provider = makeProvider(network: network, format: .responses)
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "hi")], model: "gpt-5")

        let response = try await provider.complete(request)

        #expect(response.content == "responses reply")
        #expect(response.model == "gpt-5")
        #expect(network.requests.first?.url?.absoluteString == "https://api.openai.com/v1/responses")
        #expect(network.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
    }

    @Test("Responses 协议回落到 output 数组里的文本")
    func responsesProtocolFallsBackToOutputArray() async throws {
        let network = FakeNetworkProvider()
        network.setResponse(data: Data(#"""
        {"output":[{"content":[{"type":"output_text","text":"part1"},{"type":"output_text","text":"part2"}]}]}
        """#.utf8))
        let provider = makeProvider(network: network, format: .responses)
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "hi")], model: "gpt-5")

        let response = try await provider.complete(request)

        #expect(response.content == "part1part2")
    }

    @Test("Responses 协议在没有任何文本时返回空串")
    func responsesProtocolReturnsEmptyText() async throws {
        let network = FakeNetworkProvider()
        network.setResponse(data: Data(#"{"output":[]}"#.utf8))
        let provider = makeProvider(network: network, format: .responses)
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "hi")], model: "gpt-5")

        let response = try await provider.complete(request)

        #expect(response.content == "")
    }

    @Test("缺少端点配置时抛出未配置错误")
    func throwsWhenEndpointIsMissing() async {
        let network = FakeNetworkProvider()
        let service = VendorAPIService(networkProvider: network, maxAttempts: 1, baseRetryDelay: 0)
        let provider = TestVendorProvider(
            info: Fixture.providerInfo(format: .openAI),
            apiService: service
        )
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "hi")])

        await #expect(throws: VendorAPIError.self) {
            try await provider.complete(request)
        }
    }

    @Test("HTTP 错误状态被转成 httpStatus 错误")
    func surfacesHTTPStatusError() async {
        let network = FakeNetworkProvider()
        network.setResponse(data: Data(#"{"error":{"message":"boom"}}"#.utf8), statusCode: 503)
        let provider = makeProvider(network: network, format: .openAI)
        let request = LLMRequest(messages: [LLMMessage(role: .user, content: "hi")])

        do {
            _ = try await provider.complete(request)
            Issue.record("应当抛出 httpStatus 错误")
        } catch let error as VendorAPIError {
            guard case let .httpStatus(statusCode, summary, _) = error else {
                Issue.record("错误类型不符: \(error)")
                return
            }
            #expect(statusCode == 503)
            #expect(summary.contains("boom"))
        } catch {
            Issue.record("错误类型不符: \(error)")
        }
    }
}

// MARK: - 流式请求

@Suite("VendorLLMProvider 流式请求")
@MainActor
struct VendorProviderStreamingTests {

    private func makeProvider(
        network: FakeNetworkProvider,
        format: LLMProviderAPIFormat
    ) -> TestVendorProvider {
        let service = VendorAPIService(networkProvider: network, maxAttempts: 1, baseRetryDelay: 0)
        let info = Fixture.providerInfo(format: format)
        return TestVendorProvider(
            info: info,
            apiService: service,
            openAI: format == .openAI ? Fixture.openAIConfig() : nil,
            anthropic: format == .anthropic ? Fixture.anthropicConfig() : nil
        )
    }

    @Test("OpenAI 兼容流式响应累积正文")
    func openAIStreamAccumulatesContent() async throws {
        let network = FakeNetworkProvider()
        network.setStreamEvents([
            Fixture.sse(["choices": [["delta": ["content": "Hel"]]]]),
            Fixture.sse(["choices": [["delta": ["content": "lo"]]]]),
            Fixture.sse(["choices": [["delta": [:], "finish_reason": "stop"]]]),
        ])
        let provider = makeProvider(network: network, format: .openAI)
        let collector = ChunkCollector()
        let request = LLMRequest(
            messages: [LLMMessage(role: .user, content: "hi")],
            model: "gpt-4o"
        )

        let response = try await provider.streamComplete(request) { chunk in
            collector.append(chunk)
        }

        #expect(collector.text == "Hello")
        #expect(response.content == "Hello")
        #expect(response.model == "gpt-4o")
        #expect(network.lastBodyJSON["stream"] as? Bool == true)
        #expect(network.lastBodyJSON["stream_options"] as? [String: Any] != nil)
    }

    @Test("Anthropic 兼容流式响应累积正文")
    func anthropicStreamAccumulatesContent() async throws {
        let network = FakeNetworkProvider()
        network.setStreamEvents([
            Fixture.anthropicSSE(
                event: "message_start",
                payload: ["type": "message_start", "message": ["id": "msg_1", "usage": ["input_tokens": 12]]]
            ),
            Fixture.anthropicSSE(
                event: "content_block_delta",
                payload: ["type": "content_block_delta", "index": 0, "delta": ["type": "text_delta", "text": "Hel"]]
            ),
            Fixture.anthropicSSE(
                event: "content_block_delta",
                payload: ["type": "content_block_delta", "index": 0, "delta": ["type": "text_delta", "text": "lo"]]
            ),
            Fixture.anthropicSSE(
                event: "message_delta",
                payload: ["type": "message_delta", "delta": ["stop_reason": "end_turn"], "usage": ["output_tokens": 4]]
            ),
            Fixture.anthropicSSE(event: "message_stop", payload: ["type": "message_stop"]),
        ])
        let provider = makeProvider(network: network, format: .anthropic)
        let collector = ChunkCollector()
        let request = LLMRequest(
            messages: [LLMMessage(role: .user, content: "hi")],
            model: "claude-sonnet-4"
        )

        let response = try await provider.streamComplete(request) { chunk in
            collector.append(chunk)
        }

        #expect(collector.text == "Hello")
        #expect(response.content == "Hello")
        #expect(response.inputTokenCount == 12)
        #expect(response.outputTokenCount == 4)
        #expect(response.responseID == "msg_1")
    }

    @Test("Responses 协议没有流式实现时回落到非流式请求")
    func responsesStreamFallsBackToCompletion() async throws {
        let network = FakeNetworkProvider()
        network.setResponse(data: Data(#"{"output_text":"fallback"}"#.utf8))
        let provider = makeProvider(network: network, format: .responses)
        let collector = ChunkCollector()
        let request = LLMRequest(
            messages: [LLMMessage(role: .user, content: "hi")],
            model: "gpt-5"
        )

        let response = try await provider.streamComplete(request) { chunk in
            collector.append(chunk)
        }

        #expect(response.content == "fallback")
        #expect(collector.chunks.isEmpty)
    }

    @Test("没有收到结束信号时拒绝不完整响应")
    func rejectsIncompleteStream() async {
        let network = FakeNetworkProvider()
        network.setStreamEvents([
            Fixture.sse(["choices": [["delta": ["content": "partial"]]]]),
        ])
        let provider = makeProvider(network: network, format: .openAI)
        let collector = ChunkCollector()
        let request = LLMRequest(
            messages: [LLMMessage(role: .user, content: "hi")],
            model: "gpt-4o"
        )

        await #expect(throws: VendorAPIError.incompleteStream) {
            try await provider.streamComplete(request) { chunk in
                collector.append(chunk)
            }
        }
    }
}

// MARK: - 辅助能力

@Suite("VendorLLMProvider 辅助能力")
@MainActor
struct VendorProviderHelperTests {

    private func makeProvider() -> TestVendorProvider {
        let service = VendorAPIService(networkProvider: FakeNetworkProvider(), maxAttempts: 1, baseRetryDelay: 0)
        return TestVendorProvider(
            info: Fixture.providerInfo(id: "helper", format: .openAI),
            apiService: service,
            openAI: Fixture.openAIConfig()
        )
    }

    @Test("供应商标识与元数据一致")
    func providerIDMatchesInfo() {
        let provider = makeProvider()

        #expect(provider.providerID == "helper")
        #expect(provider.providerInfo.id == "helper")
        #expect(provider.availableModels.map(\.id) == ["default-model"])
        #expect(provider.usesRemoteModelList == false)
        #expect(provider.lastModelSyncDate == nil)
    }

    @Test("工具 schema 转成适配器可用的形态并带回查映射")
    func toolSchemasBuildReverseMap() throws {
        let provider = makeProvider()
        let schemas = [LLMFunctionSchema(name: "app.read", description: "读取", parameters: [:])]

        let (tools, reverseMap) = provider.toolSchemas(from: schemas)

        #expect(tools?.count == 1)
        #expect(reverseMap?["app_read"] == "app.read")
    }

    @Test("没有工具时返回空的可选值")
    func toolSchemasAreNilWhenEmpty() {
        let provider = makeProvider()

        let (nilTools, nilMap) = provider.toolSchemas(from: nil)
        #expect(nilTools == nil)
        #expect(nilMap == nil)

        let (emptyTools, emptyMap) = provider.toolSchemas(from: [])
        #expect(emptyTools == nil)
        #expect(emptyMap == nil)
    }

    @Test("推理档位归一化并拒绝未知取值")
    func normalizesReasoningEffort() {
        let provider = makeProvider()

        #expect(provider.normalizedReasoningEffort(" HIGH ") == "high")
        #expect(provider.normalizedReasoningEffort("xhigh") == "xhigh")
        #expect(provider.normalizedReasoningEffort("max") == "max")
        #expect(provider.normalizedReasoningEffort("auto") == nil)
        #expect(provider.normalizedReasoningEffort("turbo") == nil)
        #expect(provider.normalizedReasoningEffort(nil) == nil)
    }
}
