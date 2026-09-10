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
        #expect(info.providerType == .cloudService)
        #expect(info.contains(model: "test-model"))
        #expect(!info.contains(model: "nonexistent"))
        #expect(info.modelIDs == ["test-model"])
    }

    @Test("本地供应商自动推导类型")
    func localProviderTypeIsInferred() {
        let info = LLMProviderInfo(
            id: "local",
            displayName: "Local",
            defaultModel: "local-model",
            models: [LLMModelInfo(id: "local-model")],
            isLocal: true
        )

        #expect(info.providerType == .local)
    }

    @Test("供应商类型支持中转站")
    func relayProviderTypeCanBeDeclared() {
        let info = LLMProviderInfo(
            id: "relay",
            displayName: "Relay",
            defaultModel: "relay-model",
            models: [LLMModelInfo(id: "relay-model")],
            providerType: .relay
        )

        #expect(info.providerType == .relay)
        #expect(info.providerType.displayName == "中转站")
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

        let streamingBody = try adapter.buildStreamingRequestBody(
            messages: messages,
            model: "gpt-4",
            tools: nil,
            systemPrompt: ""
        )
        #expect((streamingBody["stream_options"] as? [String: Bool])?["include_usage"] == true)
    }

    @Test("OpenAI adapter 拒绝非法工具参数，避免把坏历史发送给供应商")
    func openAIAdapterRejectsInvalidToolArguments() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(baseURL: "https://api.openai.com/v1")
        )
        let malformed = #"{"mode":"choice","options":[{"label":"混合展示"},{"label":"不新增栏"},{"label":"Frequent 内部分"label\": \"Frequent 内部分组\"}]}"#
        let messages = [LLMMessage(
            role: .assistant,
            content: "",
            toolCalls: [LLMToolCall(id: "call-bad", name: "ask_user", arguments: malformed)]
        )]

        #expect(throws: LLMToolCallValidationError.self) {
            _ = try adapter.buildRequestBody(messages: messages, model: "gpt-4", tools: nil, systemPrompt: "")
        }
    }

    @Test("LLM 响应在落库前拒绝非法工具参数")
    func responseRejectsInvalidToolArguments() {
        let response = LLMResponse(
            content: "",
            toolCalls: [LLMToolCall(id: "call-bad", name: "ask_user", arguments: #"{"label": "broken"label}"#)]
        )

        #expect(throws: LLMToolCallValidationError.self) {
            try response.validateToolCallArguments()
        }
    }

    @Test("OpenAI 兼容流式解析器兼容 input/output token 字段")
    func openAIAdapterParsesUsageAliases() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(baseURL: "https://example.com")
        )
        let event = "data: {\"choices\":[],\"usage\":{\"input_tokens\":12,\"output_tokens\":8}}\n\n"
        let chunk = try adapter.parseStreamChunk(data: Data(event.utf8))

        #expect(chunk?.inputTokens == 12)
        #expect(chunk?.outputTokens == 8)
    }

    @Test("OpenAI 兼容流式解析器识别 finish_reason")
    func openAIAdapterParsesFinishReason() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(baseURL: "https://example.com")
        )
        let event = "data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\n"
        let chunk = try adapter.parseStreamChunk(data: Data(event.utf8))

        #expect(chunk?.stopReason == "stop")
    }

    @Test("DeepSeek 最终结束块保留 usage 和缓存命中字段")
    func openAIAdapterParsesDeepSeekFinalUsageChunk() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(baseURL: "https://api.deepseek.com/v1")
        )
        let event = """
        data: {"choices":[{"delta":{},"finish_reason":"stop"}],"usage":{"prompt_tokens":123,"completion_tokens":17,"prompt_cache_hit_tokens":100,"prompt_cache_miss_tokens":23}}

        """
        let chunk = try adapter.parseStreamChunk(data: Data(event.utf8))

        #expect(chunk?.inputTokens == 123)
        #expect(chunk?.outputTokens == 17)
        #expect(chunk?.cachedInputTokens == 100)
        #expect(chunk?.cacheTotalInputTokens == 123)
        #expect(chunk?.stopReason == "stop")
    }

    @Test("OpenAI 兼容请求过滤授权占位并去重旧工具结果")
    func openAIAdapterRepairsDuplicateToolResults() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(baseURL: "https://api.deepseek.com/v1")
        )
        let messages = [
            LLMMessage(
                role: .assistant,
                content: "",
                toolCalls: [
                    LLMToolCall(id: "call-edit", name: "edit_file", arguments: "{}"),
                    LLMToolCall(id: "call-read", name: "read_file", arguments: "{}"),
                ]
            ),
            LLMMessage(
                role: .tool,
                content: #"{"kind":"permission","toolCallID":"approval:call-edit"}"#,
                toolCallID: "call-edit"
            ),
            LLMMessage(role: .tool, content: "read result", toolCallID: "call-read"),
            LLMMessage(role: .tool, content: "edit result", toolCallID: "call-edit"),
        ]

        let body = try adapter.buildRequestBody(
            messages: messages,
            model: "deepseek-v4-flash",
            tools: nil,
            systemPrompt: ""
        )
        let bodyMessages = body["messages"] as? [[String: Any]]

        #expect(bodyMessages?.count == 3)
        #expect(bodyMessages?[1]["tool_call_id"] as? String == "call-read")
        #expect(bodyMessages?[1]["content"] as? String == "read result")
        #expect(bodyMessages?[2]["tool_call_id"] as? String == "call-edit")
        #expect(bodyMessages?[2]["content"] as? String == "edit result")
    }

    @Test("OpenAI 兼容请求将迟到的交互工具结果移到 assistant 后")
    func openAIAdapterRepairsOutOfOrderToolResult() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(baseURL: "https://api.deepseek.com/v1")
        )
        let messages = [
            LLMMessage(
                role: .assistant,
                content: "",
                toolCalls: [LLMToolCall(id: "ask-1", name: "ask_user", arguments: "{}")]
            ),
            LLMMessage(role: .user, content: "继续提交这次修改"),
            LLMMessage(
                role: .tool,
                content: "The user continued without answering.",
                toolCallID: "ask-1"
            ),
        ]

        let body = try adapter.buildRequestBody(
            messages: messages,
            model: "deepseek-v4-flash",
            tools: nil,
            systemPrompt: ""
        )
        let bodyMessages = body["messages"] as? [[String: Any]]

        #expect(bodyMessages?.count == 3)
        #expect(bodyMessages?[1]["role"] as? String == "tool")
        #expect(bodyMessages?[1]["tool_call_id"] as? String == "ask-1")
        #expect(bodyMessages?[2]["role"] as? String == "user")
        #expect(bodyMessages?[2]["content"] as? String == "继续提交这次修改")
    }

    @Test("OpenAI 兼容请求移除无结果的孤立工具调用")
    func openAIAdapterRemovesOrphanToolCalls() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(baseURL: "https://api.deepseek.com/v1")
        )
        let messages = [
            LLMMessage(
                role: .assistant,
                content: "等待用户回答",
                toolCalls: [LLMToolCall(id: "orphan", name: "ask_user", arguments: "{}")]
            ),
            LLMMessage(role: .user, content: "继续")
        ]

        let body = try adapter.buildRequestBody(
            messages: messages,
            model: "deepseek-v4-flash",
            tools: nil,
            systemPrompt: ""
        )
        let bodyMessages = body["messages"] as? [[String: Any]]

        #expect(bodyMessages?.count == 2)
        #expect(bodyMessages?[0]["tool_calls"] == nil)
        #expect(bodyMessages?[0]["content"] as? String == "等待用户回答")
    }

    @Test("未收到流式终止信号时拒绝不完整响应")
    func incompleteStreamingResponseFails() async {
        let accumulator = StreamingAccumulator()
        _ = await accumulator.consume(
            StreamChunk(content: "partial", eventType: .textDelta),
            onChunk: { _ in }
        )

        do {
            _ = try await accumulator.finish(model: "test-model")
            Issue.record("不完整流不应被当作成功响应")
        } catch let error as VendorAPIError {
            #expect(error == .incompleteStream)
        } catch {
            Issue.record("收到意外错误：\(error)")
        }
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

    @Test("Anthropic 缓存配置在最后文本块添加显式边界")
    func anthropicAdapterAddsPromptCacheBoundaryWhenEnabled() throws {
        let adapter = AnthropicCompatibleProviderAdapter(
            configuration: AnthropicCompatibleProviderConfiguration(
                baseURL: "https://example.com",
                enablesPromptCaching: true
            )
        )
        let body = try adapter.buildRequestBody(
            messages: [LLMMessage(role: .user, content: "stable context")],
            model: "qwen3.7-plus",
            tools: nil,
            systemPrompt: ""
        )

        let messages = body["messages"] as? [[String: Any]]
        let content = messages?.last?["content"] as? [[String: Any]]
        #expect(content?.last?["cache_control"] as? [String: String] == ["type": "ephemeral"])
    }

    @Test("Anthropic usage 兼容阿里云缓存读取和创建字段")
    func anthropicAdapterParsesCacheUsage() throws {
        let adapter = AnthropicCompatibleProviderAdapter(
            configuration: AnthropicCompatibleProviderConfiguration(baseURL: "https://example.com")
        )
        let event = """
        event: message_start
        data: {"type":"message_start","message":{"usage":{"input_tokens":82,"cache_creation_input_tokens":1536,"cache_read_input_tokens":0}}}

        """
        let chunk = try adapter.parseStreamChunk(data: Data(event.utf8))

        #expect(chunk?.inputTokens == 82)
        #expect(chunk?.cachedInputTokens == 0)
        #expect(chunk?.cacheWriteInputTokens == 1536)
        #expect(chunk?.cacheTotalInputTokens == 1618)
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

    @Test("流式计时器记录首个输出和流式时长")
    func streamTimingRecorder() {
        let recorder = LLMStreamTimingRecorder()
        recorder.markFirstOutput()

        let timing = recorder.finish()

        #expect(timing.latencyMs >= 0)
        #expect(timing.timeToFirstTokenMs != nil)
        #expect(timing.streamingDurationMs != nil)
        #expect((timing.streamingDurationMs ?? 0) <= timing.latencyMs)
    }

    @Test("没有输出时不伪造流式时长")
    func streamTimingWithoutOutput() {
        let timing = LLMStreamTimingRecorder().finish()

        #expect(timing.latencyMs >= 0)
        #expect(timing.timeToFirstTokenMs == nil)
        #expect(timing.streamingDurationMs == nil)
    }
}
