import Foundation
import KitAgentTool
import Testing
@testable import KitLLM

/// 非流式响应解析的**线程归属**契约（Issue #1270）。
///
/// 核心要求：响应解析（整份 JSON 解码 + 内联生成图片的 base64 解码）
/// 不在主线程上同步执行。
///
/// 实测依据：`nonisolated` 函数从主 actor 调用时**仍在主线程**，
/// `Task {}`（继承 actor 上下文）同样如此——只有 `Task.detached`
/// 才会真正离开。
@Suite("非流式响应解析的线程归属")
struct NonStreamingResponseThreadTests {

    // MARK: - 测试替身

    /// 可编程的网络替身：返回预设响应。
    private final class FakeNetworkProvider: LLMNetworkProviding, @unchecked Sendable {
        private let lock = NSLock()
        private var storedResponse = Data()

        func setResponse(data: Data) {
            lock.withLock { storedResponse = data }
        }

        func send(request: URLRequest, body: Data) async throws -> (Data, URLResponse) {
            let data = lock.withLock { storedResponse }
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (data, response)
        }

        func stream(
            request: URLRequest,
            body: Data,
            onEvent: @escaping @Sendable (Data) async -> Bool
        ) async throws {
            _ = try await send(request: request, body: body)
        }
    }

    /// 测试用 provider：覆盖 OpenAI 兼容协议配置。
    @MainActor
    private final class TestProvider: VendorLLMProvider {
        override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
            OpenAICompatibleProviderConfiguration(baseURL: "https://example.com")
        }

        // 测试不访问 Keychain，直接给固定 Key。
        override func hasApiKey() -> Bool { true }
        override func getApiKey() -> String { "test-key" }
        override func resolveAPIKey() throws -> String { "test-key" }
        override func setApiKey(_ apiKey: String) {}
        override func removeApiKey() {}
    }

    // MARK: - 辅助

    @MainActor
    private func makeProvider(responseData: Data) -> TestProvider {
        let network = FakeNetworkProvider()
        network.setResponse(data: responseData)
        let service = VendorAPIService(
            networkProvider: network,
            maxAttempts: 1,
            baseRetryDelay: 0
        )
        let info = LLMProviderInfo(
            id: "test",
            displayName: "Test",
            defaultModel: "test-model",
            models: [],
            isLocal: true
        )
        return TestProvider(info: info, apiService: service)
    }

    private func responseData(
        content: String = "你好",
        includeImage: Bool = false
    ) throws -> Data {
        var message: [String: Any] = ["role": "assistant", "content": content]
        if includeImage {
            message["images"] = [[
                "type": "image_url",
                "image_url": [
                    "url": "data:image/png;base64,\(Data(repeating: 0x42, count: 2_000_000).base64EncodedString())"
                ]
            ]]
        }
        return try JSONSerialization.data(withJSONObject: [
            "id": "chatcmpl-1",
            "choices": [[
                "index": 0,
                "message": message,
                "finish_reason": "stop"
            ]],
            "usage": ["prompt_tokens": 10, "completion_tokens": 5]
        ])
    }

    // MARK: - 线程归属

    @MainActor
    @Test("响应解析不在主线程上执行")
    func responseParsingRunsOffMainThread() async throws {
        let provider = makeProvider(responseData: try responseData())
        OpenAICompatibleProviderAdapter.responseParseCounter.reset()

        _ = try await provider.complete(
            LLMRequest(messages: [LLMMessage(role: .user, content: "hi")])
        )

        #expect(
            OpenAICompatibleProviderAdapter.responseParseCounter.count >= 1,
            "响应应被解析"
        )
        #expect(
            OpenAICompatibleProviderAdapter.responseParseCounter.mainThreadCount == 0,
            "响应解析不得在主线程上执行"
        )
    }

    @MainActor
    @Test("含内联生成图片的响应解析也不在主线程上执行")
    func imageResponseParsingRunsOffMainThread() async throws {
        let provider = makeProvider(responseData: try responseData(includeImage: true))
        OpenAICompatibleProviderAdapter.responseParseCounter.reset()

        let response = try await provider.complete(
            LLMRequest(messages: [LLMMessage(role: .user, content: "生成一张图")])
        )

        #expect(response.images?.count == 1)
        #expect(
            OpenAICompatibleProviderAdapter.responseParseCounter.mainThreadCount == 0,
            "响应解析（含图片 base64 解码）不得在主线程上执行"
        )
    }

    @MainActor
    @Test("解析在后台线程时响应内容仍然完整")
    func responseContentIsIntactWhenParsedOffMainThread() async throws {
        let provider = makeProvider(responseData: try responseData(content: "完整的响应内容"))

        let response = try await provider.complete(
            LLMRequest(messages: [LLMMessage(role: .user, content: "hi")])
        )

        #expect(response.content == "完整的响应内容")
        #expect(response.inputTokenCount == 10)
        #expect(response.outputTokenCount == 5)
        #expect(response.responseID == "chatcmpl-1")
    }
}
