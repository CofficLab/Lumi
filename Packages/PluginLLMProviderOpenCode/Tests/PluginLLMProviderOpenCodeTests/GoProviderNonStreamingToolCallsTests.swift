import Foundation
import KitLLM
import Testing
@testable import PluginLLMProviderOpenCode

/// OpenCode Go 的非流式响应必须带上解析出的工具调用。
///
/// ## 为什么要有这条测试
///
/// Chat Completions 与 Anthropic 的非流式分支都成功解析出了工具调用，
/// 却没有把它放进 `LLMResponse`——`LLMResponse.toolCalls` 的默认值是
/// `nil`，所以这两处构造会静默编译通过并丢掉数据。
///
/// 结果是：一次合法的「只调用工具」的响应被当成空文本响应返回，调用方
/// 无法区分它与空响应，也就无法执行被请求的工具。
@MainActor
struct GoProviderNonStreamingToolCallsTests {

    private static let storageKey = "DevAssistant_ApiKey_OpenCodeGo"

    /// 把 API Key 写入**一次性**的 Keychain service，绝不碰生产 service。
    private static func withIsolatedAPIKey(_ value: String) {
        VendorAPIKeyTools.keychainService = "com.coffic.lumi.apikey.test.\(UUID().uuidString)"
        VendorAPIKeyTools.set(value, storageKey: storageKey)
    }

    /// 返回固定 JSON 的网络桩。
    private final class NonStreamingNetworkStub: LLMNetworkProviding, @unchecked Sendable {
        let payload: Data

        init(payload: Data) {
            self.payload = payload
        }

        func send(request: URLRequest, body: Data) async throws -> (Data, URLResponse) {
            let url = request.url ?? URL(string: "https://example.invalid")!
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (payload, response)
        }

        func stream(
            request: URLRequest,
            body: Data,
            onEvent: @Sendable @escaping (Data) async -> Bool
        ) async throws {}
    }

    private func makeProvider(payload: String) -> GoProvider {
        let network = NonStreamingNetworkStub(payload: Data(payload.utf8))
        let service = VendorAPIService(networkProvider: network, maxAttempts: 1)
        return GoProvider(apiService: service)
    }

    private func makeRequest(model: String) -> LLMRequest {
        LLMRequest(
            messages: [LLMMessage(role: .user, content: "read a")],
            model: model,
            tools: [
                LLMFunctionSchema(
                    name: "read_file",
                    description: "Read a file",
                    parameters: ["type": "object"]
                )
            ]
        )
    }

    // MARK: - Tests

    @Test("Chat Completions 非流式响应带上工具调用")
    func openAINonStreamingKeepsToolCalls() async throws {
        let provider = makeProvider(payload: """
        {"choices":[{"message":{"role":"assistant","content":null,"tool_calls":\
        [{"id":"call_1","function":{"name":"read_file","arguments":"{\\"path\\":\\"a\\"}"}}]}}]}
        """)
        Self.withIsolatedAPIKey("sk-test-opencode-go")
        defer { VendorAPIKeyTools.remove(storageKey: Self.storageKey) }

        let response = try await provider.complete(makeRequest(model: "deepseek-v4-flash"))

        let call = try #require(response.toolCalls?.first, "工具调用被丢弃了")
        #expect(call.id == "call_1")
        #expect(call.name == "read_file")
        #expect(call.arguments == #"{"path":"a"}"#)
    }

    @Test("Anthropic 非流式响应带上工具调用")
    func anthropicNonStreamingKeepsToolCalls() async throws {
        let provider = makeProvider(payload: """
        {"content":[{"type":"tool_use","id":"call_1","name":"read_file","input":{"path":"a"}}]}
        """)
        Self.withIsolatedAPIKey("sk-test-opencode-go")
        defer { VendorAPIKeyTools.remove(storageKey: Self.storageKey) }

        let response = try await provider.complete(makeRequest(model: "qwen3.7-plus"))

        let call = try #require(response.toolCalls?.first, "工具调用被丢弃了")
        #expect(call.id == "call_1")
        #expect(call.name == "read_file")
        #expect(call.arguments == #"{"path":"a"}"#)
    }

    @Test("非流式响应没有工具时工具列表为空")
    func nonStreamingWithoutToolCallsHasNoCalls() async throws {
        let provider = makeProvider(payload: """
        {"choices":[{"message":{"role":"assistant","content":"hello"}}]}
        """)
        Self.withIsolatedAPIKey("sk-test-opencode-go")
        defer { VendorAPIKeyTools.remove(storageKey: Self.storageKey) }

        let response = try await provider.complete(makeRequest(model: "deepseek-v4-flash"))

        #expect(response.content == "hello")
        #expect(response.toolCalls?.isEmpty ?? true)
    }
}
