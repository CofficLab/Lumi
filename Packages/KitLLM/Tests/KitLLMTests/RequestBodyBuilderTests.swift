import Foundation
import Testing
@testable import KitLLM

/// 请求体构建的离主线程契约（Issue #1269）。
///
/// 核心诉求：请求体构建与 JSON 序列化**不在主线程上同步执行**。
///
/// 这条契约无法只靠「代码看起来是 async」来保证——实测表明，
/// `nonisolated` 静态函数和 `Task {}` 都会**继续跑在主线程上**，
/// 只有 `Task.detached` 才会真正离开。因此这里用一个「记录执行线程的
/// 工具 schema」直接断言线程归属。
@Suite("RequestBodyBuilder 离主线程构建")
struct RequestBodyBuilderTests {

    /// `Thread.isMainThread` 在 async 上下文不可用，用 pthread API 判定。
    nonisolated static func isMainThread() -> Bool {
        pthread_main_np() != 0
    }

    /// 一个会记录自身被访问时线程的工具 schema。
    ///
    /// `inputSchema` 在适配器构建工具定义时被读取，因此它能探知
    /// 「请求体构建到底跑在哪个线程上」。
    private final class ThreadProbingToolSchema: LLMToolSchemaProviding, @unchecked Sendable {
        let name = "probe"
        let toolDescription = "probe"

        private let lock = NSLock()
        private var _sawMainThread: Bool?

        /// 构建期间是否在主线程上被访问过。
        var sawMainThread: Bool? {
            lock.lock()
            defer { lock.unlock() }
            return _sawMainThread
        }

        var inputSchema: [String: Any] {
            lock.lock()
            _sawMainThread = RequestBodyBuilderTests.isMainThread()
            lock.unlock()
            return ["type": "object"]
        }
    }

    // MARK: - 线程归属

    @Test("OpenAI 流式请求体不在主线程上构建")
    @MainActor
    func openAIStreamingBodyBuildsOffMainThread() async throws {
        let configuration = OpenAICompatibleProviderConfiguration(baseURL: "https://example.com")
        let config = LLMConfig(model: "test-model", providerId: "test")
        let probe = ThreadProbingToolSchema()

        // 从主线程上下文发起，验证构建过程确实离开了主线程。
        let data = try await RequestBodyBuilder.openAIStreamingBody(
            messages: [LLMMessage(role: .user, content: "hi")],
            model: "test-model",
            tools: [probe],
            config: config,
            configuration: configuration
        )

        #expect(!data.isEmpty)
        let sawMain = try #require(probe.sawMainThread, "工具 schema 应在构建时被读取")
        #expect(sawMain == false, "请求体构建不得在主线程上执行")
    }

    @Test("OpenAI 非流式请求体不在主线程上构建")
    @MainActor
    func openAIBodyBuildsOffMainThread() async throws {
        let configuration = OpenAICompatibleProviderConfiguration(baseURL: "https://example.com")
        let config = LLMConfig(model: "test-model", providerId: "test")
        let probe = ThreadProbingToolSchema()

        let data = try await RequestBodyBuilder.openAIBody(
            messages: [LLMMessage(role: .user, content: "hi")],
            model: "test-model",
            tools: [probe],
            config: config,
            configuration: configuration
        )

        #expect(!data.isEmpty)
        let sawMain = try #require(probe.sawMainThread, "工具 schema 应在构建时被读取")
        #expect(sawMain == false, "请求体构建不得在主线程上执行")
    }

    @Test("Anthropic 请求体不在主线程上构建")
    @MainActor
    func anthropicBodyBuildsOffMainThread() async throws {
        let configuration = AnthropicCompatibleProviderConfiguration(baseURL: "https://example.com")
        let config = LLMConfig(model: "test-model", providerId: "test")
        let probe = ThreadProbingToolSchema()

        let data = try await RequestBodyBuilder.anthropicBody(
            messages: [LLMMessage(role: .user, content: "hi")],
            model: "test-model",
            tools: [probe],
            config: config,
            configuration: configuration
        )

        #expect(!data.isEmpty)
        let sawMain = try #require(probe.sawMainThread, "工具 schema 应在构建时被读取")
        #expect(sawMain == false, "请求体构建不得在主线程上执行")
    }

    @Test("Anthropic 流式请求体不在主线程上构建")
    @MainActor
    func anthropicStreamingBodyBuildsOffMainThread() async throws {
        let configuration = AnthropicCompatibleProviderConfiguration(baseURL: "https://example.com")
        let config = LLMConfig(model: "test-model", providerId: "test")
        let probe = ThreadProbingToolSchema()

        let data = try await RequestBodyBuilder.anthropicStreamingBody(
            messages: [LLMMessage(role: .user, content: "hi")],
            model: "test-model",
            tools: [probe],
            config: config,
            configuration: configuration
        )

        #expect(!data.isEmpty)
        let sawMain = try #require(probe.sawMainThread, "工具 schema 应在构建时被读取")
        #expect(sawMain == false, "请求体构建不得在主线程上执行")
    }

    // MARK: - 请求体语义不变

    @Test("请求体内容与适配器直接构建的结果一致")
    func bodyMatchesAdapterDirectBuild() async throws {
        let configuration = OpenAICompatibleProviderConfiguration(baseURL: "https://example.com")
        let config = LLMConfig(model: "test-model", providerId: "test")
        let messages = [
            LLMMessage(role: .system, content: "you are helpful"),
            LLMMessage(role: .user, content: "hello"),
            LLMMessage(role: .assistant, content: "hi"),
        ]

        let adapter = OpenAICompatibleProviderAdapter(configuration: configuration)
        let expected = try adapter.buildStreamingRequestBody(
            messages: messages,
            model: "test-model",
            tools: nil,
            systemPrompt: "",
            config: config
        )
        let expectedData = try JSONSerialization.data(withJSONObject: expected, options: [.sortedKeys])

        let actual = try await RequestBodyBuilder.openAIStreamingBody(
            messages: messages,
            model: "test-model",
            tools: nil,
            config: config,
            configuration: configuration
        )

        #expect(actual == expectedData)
    }

    @Test("图片消息的请求体内容不变")
    func bodyWithImagesIsUnchanged() async throws {
        let configuration = OpenAICompatibleProviderConfiguration(baseURL: "https://example.com")
        let config = LLMConfig(model: "test-model", providerId: "test")
        let image = MessageImage(data: Data(repeating: 0x42, count: 256), mimeType: "image/png")
        let messages = [
            LLMMessage(role: .user, content: "看图", images: [image])
        ]

        let adapter = OpenAICompatibleProviderAdapter(configuration: configuration)
        let expected = try adapter.buildStreamingRequestBody(
            messages: messages,
            model: "test-model",
            tools: nil,
            systemPrompt: "",
            config: config
        )
        let expectedData = try JSONSerialization.data(withJSONObject: expected, options: [.sortedKeys])

        let actual = try await RequestBodyBuilder.openAIStreamingBody(
            messages: messages,
            model: "test-model",
            tools: nil,
            config: config,
            configuration: configuration
        )

        #expect(actual == expectedData)
    }

    @Test("工具调用的请求体内容不变")
    func bodyWithToolCallsIsUnchanged() async throws {
        let configuration = OpenAICompatibleProviderConfiguration(baseURL: "https://example.com")
        let config = LLMConfig(model: "test-model", providerId: "test")
        let messages = [
            LLMMessage(
                role: .assistant,
                content: "",
                toolCalls: [LLMToolCall(id: "call-1", name: "read_file", arguments: #"{"path":"/tmp/a"}"#)]
            )
        ]

        let adapter = OpenAICompatibleProviderAdapter(configuration: configuration)
        let expected = try adapter.buildStreamingRequestBody(
            messages: messages,
            model: "test-model",
            tools: nil,
            systemPrompt: "",
            config: config
        )
        let expectedData = try JSONSerialization.data(withJSONObject: expected, options: [.sortedKeys])

        let actual = try await RequestBodyBuilder.openAIStreamingBody(
            messages: messages,
            model: "test-model",
            tools: nil,
            config: config,
            configuration: configuration
        )

        #expect(actual == expectedData)
    }

    @Test("非法工具参数仍然抛错")
    func invalidToolArgumentsStillThrow() async {
        let configuration = OpenAICompatibleProviderConfiguration(baseURL: "https://example.com")
        let config = LLMConfig(model: "test-model", providerId: "test")
        let messages = [
            LLMMessage(
                role: .assistant,
                content: "",
                toolCalls: [LLMToolCall(id: "call-bad", name: "read_file", arguments: #"{"broken"label":}"#)]
            )
        ]

        await #expect(throws: LLMToolCallValidationError.self) {
            try await RequestBodyBuilder.openAIStreamingBody(
                messages: messages,
                model: "test-model",
                tools: nil,
                config: config,
                configuration: configuration
            )
        }
    }
}
