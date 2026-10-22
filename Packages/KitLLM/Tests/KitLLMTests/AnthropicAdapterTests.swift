import Foundation
import Testing
@testable import KitLLM

// MARK: - 测试替身

/// Anthropic 工具 schema 替身。
private struct AnthropicToolStub: LLMToolSchemaProviding, @unchecked Sendable {
    let name: String
    var toolDescription: String { "工具说明" }
    var inputSchema: [String: Any] { ["type": "object"] }
}

/// 把 SSE 负载组装成 Anthropic 事件块。
private func anthropicEvent(_ event: String, _ payload: [String: Any]) -> Data {
    let data = try! JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    let json = String(decoding: data, as: UTF8.self)
    return Data("event: \(event)\ndata: \(json)\n\n".utf8)
}

// MARK: - 请求构建

@Suite("Anthropic 适配器请求构建")
struct AnthropicAdapterRequestTests {

    private func makeAdapter(
        enablesPromptCaching: Bool = false,
        defaultMaxTokens: Int = 4096
    ) -> AnthropicCompatibleProviderAdapter {
        AnthropicCompatibleProviderAdapter(
            configuration: AnthropicCompatibleProviderConfiguration(
                baseURL: "https://api.example.com/v1/messages",
                additionalHeaders: ["X-Provider": "test"],
                defaultMaxTokens: defaultMaxTokens,
                enablesPromptCaching: enablesPromptCaching
            )
        )
    }

    @Test("HTTP 请求带认证头与协议版本")
    func buildsRequestHeaders() throws {
        let adapter = makeAdapter()
        let url = try #require(URL(string: "https://api.example.com/v1/messages"))

        let request = adapter.buildRequest(url: url, apiKey: "secret")

        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "secret")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "X-Provider") == "test")
    }

    @Test("请求体包含模型、最大输出与 system 兜底")
    func buildsRequestBody() throws {
        let adapter = makeAdapter()
        let messages = [LLMMessage(role: .user, content: "hi")]

        let body = try adapter.buildRequestBody(
            messages: messages,
            model: "claude-sonnet-4",
            tools: nil,
            systemPrompt: "系统提示"
        )

        #expect(body["model"] as? String == "claude-sonnet-4")
        #expect(body["max_tokens"] as? Int == 4096)
        #expect(body["system"] as? String == "系统提示")
        #expect(body["tools"] == nil)
        #expect((body["messages"] as? [[String: Any]])?.count == 1)
    }

    @Test("多条 system 消息优先于 systemPrompt")
    func systemMessagesOverridePrompt() throws {
        let adapter = makeAdapter()
        let messages = [
            LLMMessage(role: .system, content: "第一段"),
            LLMMessage(role: .system, content: "第二段"),
            LLMMessage(role: .user, content: "hi"),
        ]

        let body = try adapter.buildRequestBody(
            messages: messages,
            model: "claude-sonnet-4",
            tools: nil,
            systemPrompt: "系统提示"
        )

        #expect(body["system"] as? String == "第一段\n\n第二段")
        #expect((body["messages"] as? [[String: Any]])?.count == 1)
    }

    @Test("只含空格的 system 消息不会被过滤掉")
    func whitespaceOnlySystemMessageIsKept() throws {
        let adapter = makeAdapter()
        let messages = [
            LLMMessage(role: .system, content: "第一段"),
            LLMMessage(role: .system, content: "  "),
            LLMMessage(role: .user, content: "hi"),
        ]

        let body = try adapter.buildRequestBody(
            messages: messages,
            model: "claude-sonnet-4",
            tools: nil,
            systemPrompt: "系统提示"
        )

        // 实现只按 isEmpty 过滤，不做 trim：空白消息会原样参与拼接。
        #expect(body["system"] as? String == "第一段\n\n  ")
    }

    @Test("工具定义使用转义后的名字与 input_schema")
    func formatsTools() throws {
        let adapter = makeAdapter()
        let tools: [any LLMToolSchemaProviding] = [AnthropicToolStub(name: "app.read")]

        let body = try adapter.buildRequestBody(
            messages: [LLMMessage(role: .user, content: "hi")],
            model: "claude-sonnet-4",
            tools: tools,
            systemPrompt: ""
        )

        let formatted = try #require(body["tools"] as? [[String: Any]])
        #expect(formatted.first?["name"] as? String == "app_read")
        #expect(formatted.first?["description"] as? String == "工具说明")
        #expect(formatted.first?["input_schema"] as? [String: Any] != nil)
    }

    @Test("非法工具参数在构建请求体时就被拒绝")
    func rejectsInvalidToolArguments() {
        let adapter = makeAdapter()
        let messages = [
            LLMMessage(
                role: .assistant,
                content: "",
                toolCalls: [LLMToolCall(id: "call-1", name: "bad", arguments: "not json")]
            )
        ]

        #expect(throws: LLMToolCallValidationError.self) {
            try adapter.buildRequestBody(
                messages: messages,
                model: "claude-sonnet-4",
                tools: nil,
                systemPrompt: ""
            )
        }
    }

    @Test("流式请求体带 stream 标记")
    func buildsStreamingBody() throws {
        let adapter = makeAdapter()

        let body = try adapter.buildStreamingRequestBody(
            messages: [LLMMessage(role: .user, content: "hi")],
            model: "claude-sonnet-4",
            tools: nil,
            systemPrompt: ""
        )

        #expect(body["stream"] as? Bool == true)
    }

    @Test("带 config 的流式请求体套用生成参数")
    func appliesGenerationOptions() throws {
        let adapter = makeAdapter()
        let config = LLMConfig(
            model: "claude-sonnet-4",
            providerId: "anthropic",
            temperature: 0.3,
            maxTokens: 2048
        )

        let body = try adapter.buildStreamingRequestBody(
            messages: [LLMMessage(role: .user, content: "hi")],
            model: "claude-sonnet-4",
            tools: nil,
            systemPrompt: "",
            config: config
        )

        #expect(body["temperature"] as? Double == 0.3)
        #expect(body["max_tokens"] as? Int == 2048)
        #expect(body["thinking"] == nil)
    }

    @Test("推理档位映射成 thinking 预算并抬高 max_tokens")
    func appliesThinkingBudget() throws {
        let adapter = makeAdapter()
        let config = LLMConfig(
            model: "claude-sonnet-4",
            providerId: "anthropic",
            reasoningEffort: "high"
        )

        let body = try adapter.buildStreamingRequestBody(
            messages: [LLMMessage(role: .user, content: "hi")],
            model: "claude-sonnet-4",
            tools: nil,
            systemPrompt: "",
            config: config
        )

        let thinking = try #require(body["thinking"] as? [String: Any])
        #expect(thinking["type"] as? String == "enabled")
        #expect(thinking["budget_tokens"] as? Int == 8192)
        #expect(body["max_tokens"] as? Int == 9216)
    }

    @Test("开启缓存时最后一条文本块带缓存边界")
    func addsPromptCacheBoundary() throws {
        let adapter = makeAdapter(enablesPromptCaching: true)

        let body = try adapter.buildRequestBody(
            messages: [LLMMessage(role: .user, content: "hi")],
            model: "claude-sonnet-4",
            tools: nil,
            systemPrompt: ""
        )

        let messages = try #require(body["messages"] as? [[String: Any]])
        let content = try #require(messages.last?["content"] as? [[String: Any]])
        #expect(content.first?["cache_control"] as? [String: Any] != nil)
    }

    @Test("关闭缓存时不写缓存边界")
    func omitsPromptCacheBoundaryByDefault() throws {
        let adapter = makeAdapter()

        let body = try adapter.buildRequestBody(
            messages: [LLMMessage(role: .user, content: "hi")],
            model: "claude-sonnet-4",
            tools: nil,
            systemPrompt: ""
        )

        let messages = try #require(body["messages"] as? [[String: Any]])
        #expect(messages.last?["content"] is String)
    }
}

// MARK: - 响应解析

@Suite("Anthropic 适配器响应解析")
struct AnthropicAdapterResponseTests {

    private let adapter = AnthropicCompatibleProviderAdapter(
        configuration: AnthropicCompatibleProviderConfiguration(baseURL: "https://api.example.com/v1/messages")
    )

    @Test("文本内容被拼接")
    func parsesTextContent() throws {
        let data = Data(#"{"content":[{"type":"text","text":"Hello"},{"type":"text","text":" World"}]}"#.utf8)

        let parsed = try adapter.parseResponse(data: data)

        #expect(parsed.content == "Hello World")
        #expect(parsed.toolCalls == nil)
    }

    @Test("工具调用被解析成结构化参数")
    func parsesToolUseBlock() throws {
        let data = Data(#"""
        {"content":[{"type":"tool_use","id":"toolu_1","name":"read_file","input":{"path":"a.txt"}}]}
        """#.utf8)

        let parsed = try adapter.parseResponse(data: data)

        let calls = try #require(parsed.toolCalls)
        #expect(calls.count == 1)
        #expect(calls.first?.id == "toolu_1")
        #expect(calls.first?.name == "read_file")
        #expect(calls.first?.arguments == #"{"path":"a.txt"}"#)
    }

    @Test("工具名按反查映射还原")
    func restoresToolNameFromReverseMap() throws {
        let data = Data(#"""
        {"content":[{"type":"tool_use","id":"toolu_1","name":"app_read","input":{}}]}
        """#.utf8)

        let parsed = try adapter.parseResponse(data: data, reverseMap: ["app_read": "app.read"])

        #expect(parsed.toolCalls?.first?.name == "app.read")
    }

    @Test("错误响应体被转成 apiError")
    func throwsAPIError() {
        let data = Data(#"{"error":{"message":"overloaded"}}"#.utf8)

        #expect(throws: AnthropicCompatibleProviderError.apiError(message: "overloaded")) {
            try adapter.parseResponse(data: data)
        }
    }
}

// MARK: - 流式解析

@Suite("Anthropic 适配器流式解析")
struct AnthropicAdapterStreamTests {

    private let adapter = AnthropicCompatibleProviderAdapter(
        configuration: AnthropicCompatibleProviderConfiguration(baseURL: "https://api.example.com/v1/messages")
    )

    @Test("message_start 事件带输入 token 与消息 id")
    func parsesMessageStart() throws {
        let chunk = try #require(try adapter.parseStreamChunk(data: anthropicEvent(
            "message_start",
            ["type": "message_start", "message": ["id": "msg_1", "usage": ["input_tokens": 12]]]
        )))

        #expect(chunk.eventType == .messageStart)
        #expect(chunk.inputTokens == 12)
        #expect(chunk.responseID == "msg_1")
    }

    @Test("message_delta 事件带输出 token 与结束原因")
    func parsesMessageDelta() throws {
        let chunk = try #require(try adapter.parseStreamChunk(data: anthropicEvent(
            "message_delta",
            ["type": "message_delta", "delta": ["stop_reason": "end_turn"], "usage": ["output_tokens": 7]]
        )))

        #expect(chunk.eventType == .messageDelta)
        #expect(chunk.outputTokens == 7)
        #expect(chunk.stopReason == "end_turn")
    }

    @Test("message_stop 事件标记流结束")
    func parsesMessageStop() throws {
        let chunk = try #require(try adapter.parseStreamChunk(data: anthropicEvent(
            "message_stop",
            ["type": "message_stop"]
        )))

        #expect(chunk.isDone)
        #expect(chunk.eventType == .messageStop)
    }

    @Test("文本内容块开始事件带正文")
    func parsesTextContentBlockStart() throws {
        let chunk = try #require(try adapter.parseStreamChunk(data: anthropicEvent(
            "content_block_start",
            ["type": "content_block_start", "index": 0, "content_block": ["type": "text", "text": "Hi"]]
        )))

        #expect(chunk.eventType == .contentBlockStart)
        #expect(chunk.content == "Hi")
    }

    @Test("工具内容块开始事件带工具调用")
    func parsesToolContentBlockStart() throws {
        let chunk = try #require(try adapter.parseStreamChunk(data: anthropicEvent(
            "content_block_start",
            [
                "type": "content_block_start",
                "index": 1,
                "content_block": ["type": "tool_use", "id": "toolu_1", "name": "read_file"],
            ]
        )))

        #expect(chunk.eventType == .contentBlockStart)
        #expect(chunk.toolCallIndex == 1)
        #expect(chunk.toolCalls?.first?.id == "toolu_1")
        #expect(chunk.toolCalls?.first?.name == "read_file")
    }

    @Test("思考内容块开始事件不带正文")
    func parsesThinkingContentBlockStart() throws {
        let chunk = try #require(try adapter.parseStreamChunk(data: anthropicEvent(
            "content_block_start",
            ["type": "content_block_start", "index": 0, "content_block": ["type": "thinking"]]
        )))

        #expect(chunk.eventType == .contentBlockStart)
        #expect(chunk.content == nil)
    }

    @Test("文本增量事件带正文")
    func parsesTextDelta() throws {
        let chunk = try #require(try adapter.parseStreamChunk(data: anthropicEvent(
            "content_block_delta",
            ["type": "content_block_delta", "index": 0, "delta": ["type": "text_delta", "text": "Hel"]]
        )))

        #expect(chunk.eventType == .textDelta)
        #expect(chunk.content == "Hel")
    }

    @Test("思考增量事件被标记为 thinking")
    func parsesThinkingDelta() throws {
        let chunk = try #require(try adapter.parseStreamChunk(data: anthropicEvent(
            "content_block_delta",
            ["type": "content_block_delta", "index": 0, "delta": ["type": "thinking_delta", "thinking": "想一下"]]
        )))

        #expect(chunk.eventType == .thinkingDelta)
        #expect(chunk.content == "想一下")
    }

    @Test("工具参数增量事件带 partial_json")
    func parsesInputJSONDelta() throws {
        let chunk = try #require(try adapter.parseStreamChunk(data: anthropicEvent(
            "content_block_delta",
            ["type": "content_block_delta", "index": 2, "delta": ["type": "input_json_delta", "partial_json": #"{"k":"v"}"#]]
        )))

        #expect(chunk.eventType == .inputJsonDelta)
        #expect(chunk.partialJson == #"{"k":"v"}"#)
        #expect(chunk.toolCallIndex == 2)
    }

    @Test("签名增量事件被单独标记")
    func parsesSignatureDelta() throws {
        let chunk = try #require(try adapter.parseStreamChunk(data: anthropicEvent(
            "content_block_delta",
            ["type": "content_block_delta", "index": 0, "delta": ["type": "signature_delta", "signature": "abc"]]
        )))

        #expect(chunk.eventType == .signatureDelta)
    }

    @Test("内容块停止事件被单独标记")
    func parsesContentBlockStop() throws {
        let chunk = try #require(try adapter.parseStreamChunk(data: anthropicEvent(
            "content_block_stop",
            ["type": "content_block_stop", "index": 0]
        )))

        #expect(chunk.eventType == .contentBlockStop)
    }

    @Test("ping 事件被单独标记")
    func parsesPing() throws {
        let chunk = try #require(try adapter.parseStreamChunk(data: anthropicEvent(
            "ping",
            ["type": "ping"]
        )))

        #expect(chunk.eventType == .ping)
    }

    @Test("错误事件带错误信息")
    func parsesErrorEvent() throws {
        let chunk = try #require(try adapter.parseStreamChunk(data: anthropicEvent(
            "error",
            ["type": "error", "error": ["message": "overloaded"]]
        )))

        #expect(chunk.error == "overloaded")
    }

    @Test("[DONE] 标记流结束")
    func parsesDoneMarker() throws {
        let chunk = try #require(try adapter.parseStreamChunk(data: Data("data: [DONE]\n\n".utf8)))

        #expect(chunk.isDone)
        #expect(chunk.eventType == .messageStop)
    }

    @Test("没有 data 行的块被忽略")
    func ignoresBlockWithoutData() throws {
        #expect(try adapter.parseStreamChunk(data: Data("event: ping\n".utf8)) == nil)
    }

    @Test("网关返回整段 JSON 时按整体响应解析")
    func parsesWholeJSONBody() throws {
        let data = Data(#"{"content":[{"type":"text","text":"whole body"}]}"#.utf8)

        let chunk = try #require(try adapter.parseStreamChunk(data: data))

        #expect(chunk.content == "whole body")
        #expect(chunk.isDone)
    }
}

// MARK: - 消息转换与缓存口径

@Suite("Anthropic 适配器消息转换")
struct AnthropicAdapterMessageTests {

    private let adapter = AnthropicCompatibleProviderAdapter(
        configuration: AnthropicCompatibleProviderConfiguration(baseURL: "https://api.example.com/v1/messages")
    )

    @Test("普通文本消息原样转换")
    func transformsPlainText() {
        let result = adapter.transformMessage(LLMMessage(role: .user, content: "hi"))

        #expect(result["role"] as? String == "user")
        #expect(result["content"] as? String == "hi")
    }

    @Test("工具结果消息转成 tool_result 块")
    func transformsToolResult() throws {
        let message = LLMMessage(role: .tool, content: "结果", toolCallID: "toolu_1")

        let result = adapter.transformMessage(message)

        let content = try #require(result["content"] as? [[String: Any]])
        #expect(content.first?["type"] as? String == "tool_result")
        #expect(content.first?["tool_use_id"] as? String == "toolu_1")
    }

    @Test("带工具调用的 assistant 消息转成 tool_use 块且名字被转义")
    func transformsAssistantToolCalls() throws {
        let message = LLMMessage(
            role: .assistant,
            content: "调用中",
            toolCalls: [LLMToolCall(id: "call-1", name: "app.read", arguments: #"{"k":"v"}"#)]
        )

        let result = adapter.transformMessage(message)

        #expect(result["role"] as? String == "assistant")
        let content = try #require(result["content"] as? [[String: Any]])
        let toolUse = try #require(content.first(where: { $0["type"] as? String == "tool_use" }))
        #expect(toolUse["id"] as? String == "call-1")
        #expect(toolUse["name"] as? String == "app_read")
        #expect(toolUse["input"] as? [String: Any] != nil)
    }

    @Test("带思考内容的 assistant 消息生成 thinking 块")
    func transformsReasoningContent() throws {
        let message = LLMMessage(
            role: .assistant,
            content: "答案",
            reasoningContent: "推理过程"
        )

        let result = adapter.transformMessage(message)

        let content = try #require(result["content"] as? [[String: Any]])
        #expect(content.first?["type"] as? String == "thinking")
        #expect(content.first?["thinking"] as? String == "推理过程")
        #expect(content.count == 2)
    }

    @Test("带图片的消息转成 base64 图片块")
    func transformsImages() throws {
        let image = MessageImage(data: Data([0x01, 0x02]), mimeType: "image/png")
        let message = LLMMessage(role: .user, content: "看图", images: [image])

        let result = adapter.transformMessage(message)

        let content = try #require(result["content"] as? [[String: Any]])
        #expect(content.first?["type"] as? String == "text")
        #expect(content.last?["type"] as? String == "image")
        let source = try #require(content.last?["source"] as? [String: Any])
        #expect(source["media_type"] as? String == "image/png")
    }

    @Test("工具定义被转成 Anthropic 形态")
    func formatsToolSchema() {
        let tool = AnthropicToolStub(name: "app.read")

        let formatted = adapter.formatTool(tool)

        #expect(formatted["name"] as? String == "app_read")
        #expect(formatted["description"] as? String == "工具说明")
        #expect(formatted["input_schema"] as? [String: Any] != nil)
    }
}

@Suite("Anthropic 缓存 token 口径")
struct AnthropicCacheTokenTests {

    @Test("官方语义下总输入就是 input_tokens")
    func officialSemanticsUseInputTokens() {
        let total = AnthropicCompatibleProviderAdapter.cacheTotalInputTokens(
            inputTokens: 100,
            cachedInputTokens: 40,
            cacheWriteInputTokens: 10
        )

        #expect(total == 100)
    }

    @Test("兼容层语义下总输入是三段之和")
    func compatibleSemanticsSumAllParts() {
        let total = AnthropicCompatibleProviderAdapter.cacheTotalInputTokens(
            inputTokens: 68,
            cachedInputTokens: 512,
            cacheWriteInputTokens: 0
        )

        #expect(total == 580)
    }

    @Test("缺少 input_tokens 时退回到缓存字段之和")
    func fallsBackToCacheFields() {
        let total = AnthropicCompatibleProviderAdapter.cacheTotalInputTokens(
            inputTokens: nil,
            cachedInputTokens: 20,
            cacheWriteInputTokens: 5
        )

        #expect(total == 25)
    }

    @Test("完全没有任何计数时返回 nil")
    func returnsNilWithoutAnyCount() {
        let total = AnthropicCompatibleProviderAdapter.cacheTotalInputTokens(
            inputTokens: nil,
            cachedInputTokens: nil,
            cacheWriteInputTokens: nil
        )

        #expect(total == nil)
    }

    @Test("缓存读取字段兼容多种命名")
    func readsCacheReadTokens() {
        #expect(
            AnthropicCompatibleProviderAdapter.cacheReadInputTokens(from: ["cache_read_input_tokens": 12]) == 12
        )
        #expect(
            AnthropicCompatibleProviderAdapter.cacheReadInputTokens(from: ["cached_tokens": 7]) == 7
        )
        #expect(
            AnthropicCompatibleProviderAdapter.cacheReadInputTokens(
                from: ["prompt_tokens_details": ["cached_tokens": 3]]
            ) == 3
        )
        #expect(AnthropicCompatibleProviderAdapter.cacheReadInputTokens(from: [:]) == nil)
    }

    @Test("缓存写入字段兼容多种命名")
    func readsCacheWriteTokens() {
        #expect(
            AnthropicCompatibleProviderAdapter.cacheWriteInputTokens(from: ["cache_creation_input_tokens": 9]) == 9
        )
        #expect(
            AnthropicCompatibleProviderAdapter.cacheWriteInputTokens(from: ["cache_write_input_tokens": 4]) == 4
        )
        #expect(
            AnthropicCompatibleProviderAdapter.cacheWriteInputTokens(
                from: ["input_tokens_details": ["cache_write_tokens": 6]]
            ) == 6
        )
        #expect(AnthropicCompatibleProviderAdapter.cacheWriteInputTokens(from: [:]) == nil)
    }
}

// MARK: - 重试决策

@Suite("Anthropic 适配器重试决策")
struct AnthropicAdapterRetryTests {

    @Test("5xx 可重试，4xx 不可重试")
    func classifiesStatusCodes() {
        let retryable = AnthropicCompatibleProviderAdapter.retryDecision(
            for: VendorAPIError.httpStatus(statusCode: 503, summary: "boom", retryAfterSeconds: nil),
            statusCode: 503,
            attempt: 1,
            maxAttempts: 3
        )
        let fatal = AnthropicCompatibleProviderAdapter.retryDecision(
            for: VendorAPIError.httpStatus(statusCode: 400, summary: "bad", retryAfterSeconds: nil),
            statusCode: 400,
            attempt: 1,
            maxAttempts: 3
        )

        #expect(retryable.shouldRetry)
        #expect(fatal.shouldRetry == false)
    }

    @Test("尝试次数用尽后不再重试")
    func stopsAfterMaxAttempts() {
        let decision = AnthropicCompatibleProviderAdapter.retryDecision(
            for: VendorAPIError.httpStatus(statusCode: 503, summary: "boom", retryAfterSeconds: nil),
            statusCode: 503,
            attempt: 3,
            maxAttempts: 3
        )

        #expect(decision.shouldRetry == false)
    }

    @Test("取消类错误不重试")
    func doesNotRetryCancelled() {
        let decision = AnthropicCompatibleProviderAdapter.retryDecision(
            for: LLMServiceError.cancelled,
            statusCode: 503,
            attempt: 1,
            maxAttempts: 3
        )

        #expect(decision.shouldRetry == false)
    }
}
