import Foundation
import Testing
@testable import KitLLM

/// 流式回调的线程安全收集器。
///
/// `StreamingAccumulator.consume` 的 `onChunk` 是 `@Sendable` 闭包，
/// 测试不能在闭包里直接改捕获的 `var`（Swift 6 并发检查会拒绝）。
private final class StreamSink: @unchecked Sendable {
    private let lock = NSLock()
    private var reasoningValue = ""
    private var textOnlyValue = ""

    /// 思考事件会同时带 `content` 与 `reasoningContent`（下游分别消费两个字段），
    /// 因此「纯正文」只统计不带 `reasoningContent` 的事件。
    var textOnly: String {
        lock.lock(); defer { lock.unlock() }
        return textOnlyValue
    }

    var reasoning: String {
        lock.lock(); defer { lock.unlock() }
        return reasoningValue
    }

    func append(_ chunk: LLMStreamChunk) {
        lock.lock(); defer { lock.unlock() }
        if let reasoning = chunk.reasoningContent { reasoningValue += reasoning }
        if chunk.reasoningContent == nil, let content = chunk.content {
            textOnlyValue += content
        }
    }
}

/// 构造一条 SSE 事件。
///
/// 用 `JSONSerialization` 而不是手写字符串：工具调用 delta 里的
/// `function.arguments` 本身是一段 JSON 字符串，手写极易漏转义或
/// 数错括号，而这类夹具错误会让解析器在测试里"复现"出与生产无关的假故障。
private func sseEvent(_ payload: [String: Any]) -> String {
    let data = try! JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    let json = String(decoding: data, as: UTF8.self)
    return "data: \(json)\n\n"
}

/// 一条标准的 OpenAI 兼容 `tool_calls` delta。
private func toolCallFixture() -> [String: Any] {
    [
        "id": "call-1",
        "type": "function",
        "function": [
            "name": "read_file",
            "arguments": #"{"k":"v"}"#,
            "index": 0,
        ],
    ]
}

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

    // MARK: - reasoning_effort 档位

    @Test("基础档位对所有 OpenAI 兼容供应商都透传")
    func openAIAdapterSendsBaseReasoningEffort() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(baseURL: "https://example.com")
        )
        for effort in ["minimal", "low", "medium", "high"] {
            let body = try adapter.buildStreamingRequestBody(
                messages: [LLMMessage(role: .user, content: "hi")],
                model: "some-model",
                tools: nil,
                systemPrompt: "",
                config: LLMConfig(model: "some-model", providerId: "test", reasoningEffort: effort)
            )
            #expect(body["reasoning_effort"] as? String == effort, "档位 \(effort) 应当透传")
        }
    }

    @Test("未声明的额外档位不下发，避免上游返回 400")
    func openAIAdapterDropsUndeclaredReasoningEffort() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(baseURL: "https://example.com")
        )
        for effort in ["xhigh", "max"] {
            let body = try adapter.buildStreamingRequestBody(
                messages: [LLMMessage(role: .user, content: "hi")],
                model: "some-model",
                tools: nil,
                systemPrompt: "",
                config: LLMConfig(model: "some-model", providerId: "test", reasoningEffort: effort)
            )
            // `reasoning_effort` 合法值因供应商而异：未知档位会让上游 400，
            // 且 400 不可重试，因此未声明时必须整条参数不下发。
            #expect(body["reasoning_effort"] == nil, "未声明的档位 \(effort) 不应下发")
        }
    }

    @Test("供应商声明的额外档位正常下发（MiniMax 支持 xhigh / max）")
    func openAIAdapterSendsDeclaredExtraReasoningEffort() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(
                baseURL: "https://api.minimaxi.com/v1/chat/completions",
                additionalReasoningEfforts: ["xhigh", "max"]
            )
        )
        for effort in ["xhigh", "max"] {
            let body = try adapter.buildStreamingRequestBody(
                messages: [LLMMessage(role: .user, content: "hi")],
                model: "MiniMax-M3.1-Flash-Preview",
                tools: nil,
                systemPrompt: "",
                config: LLMConfig(model: "MiniMax-M3.1-Flash-Preview", providerId: "minimax", reasoningEffort: effort)
            )
            #expect(body["reasoning_effort"] as? String == effort, "档位 \(effort) 应当下发")
        }
    }

    @Test("档位归一化忽略大小写与空白，并拒绝 auto")
    func reasoningEffortNormalization() {
        #expect(OpenAICompatibleGenerationOptionsApplier.normalizedReasoningEffort(" HIGH ") == "high")
        #expect(OpenAICompatibleGenerationOptionsApplier.normalizedReasoningEffort("auto") == nil)
        #expect(OpenAICompatibleGenerationOptionsApplier.normalizedReasoningEffort("automatic") == nil)
        #expect(OpenAICompatibleGenerationOptionsApplier.normalizedReasoningEffort(nil) == nil)
        #expect(OpenAICompatibleGenerationOptionsApplier.normalizedReasoningEffort("bogus") == nil)
    }

    @Test("额外档位声明在构造时归一化为小写")
    func additionalReasoningEffortsAreNormalized() {
        let configuration = OpenAICompatibleProviderConfiguration(
            baseURL: "https://example.com",
            additionalReasoningEfforts: ["XHigh", "  MAX  ", ""]
        )
        #expect(configuration.additionalReasoningEfforts == ["xhigh", "max"])

        let body = OpenAICompatibleGenerationOptionsApplier.normalizedReasoningEffort(
            "XHIGH",
            additionalReasoningEfforts: configuration.additionalReasoningEfforts
        )
        #expect(body == "xhigh")
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
        let chunk = try adapter.parseStreamChunks(data: Data(event.utf8)).first

        #expect(chunk?.inputTokens == 12)
        #expect(chunk?.outputTokens == 8)
    }

    @Test("OpenAI 兼容流式解析器识别 finish_reason")
    func openAIAdapterParsesFinishReason() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(baseURL: "https://example.com")
        )
        let event = "data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\n"
        let chunk = try adapter.parseStreamChunks(data: Data(event.utf8)).first

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
        let chunk = try adapter.parseStreamChunks(data: Data(event.utf8)).first

        #expect(chunk?.inputTokens == 123)
        #expect(chunk?.outputTokens == 17)
        #expect(chunk?.cachedInputTokens == 100)
        #expect(chunk?.cacheTotalInputTokens == 123)
        #expect(chunk?.stopReason == "stop")
    }

    // MARK: - Interleaved thinking（思考与正文同 delta）

    @Test("同一 delta 同时含思考与正文时两者都保留，不丢弃正文")
    func openAIAdapterKeepsContentWhenInterleavedWithReasoning() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(baseURL: "https://api.minimaxi.com/v1")
        )
        let event = """
        data: {"id":"x","choices":[{"index":0,"delta":{"role":"assistant","reasoning_content":"让我想想","content":"最终答案"}}],"model":"MiniMax-M3.1-Flash-Preview"}

        """
        let chunks = try adapter.parseStreamChunks(data: Data(event.utf8))

        #expect(chunks.count == 2)

        let thinking = chunks.first { $0.eventType == .thinkingDelta }
        let text = chunks.first { $0.eventType == .textDelta }

        // 回归的核心断言：正文曾因优先返回思考而被静默丢弃，
        // 导致累积器 content 恒空、AgentLoop 判为「模型返回空响应」。
        #expect(thinking?.content == "让我想想")
        #expect(text?.content == "最终答案")
    }

    @Test("interleaved thinking 累积后正文非空，思考与正文各自完整")
    func openAIAdapterAccumulatorPreservesInterleavedContent() async throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(baseURL: "https://api.minimaxi.com/v1")
        )
        let events = [
            """
            data: {"choices":[{"index":0,"delta":{"reasoning_content":"思考 A"}}],"model":"MiniMax-M3.1-Flash-Preview"}

            """,
            """
            data: {"choices":[{"index":0,"delta":{"reasoning_content":"思考 B","content":"正文 A"}}],"model":"MiniMax-M3.1-Flash-Preview"}

            """,
            """
            data: {"choices":[{"index":0,"delta":{"content":"正文 B"}}],"model":"MiniMax-M3.1-Flash-Preview"}

            """,
            "data: [DONE]\n\n",
        ]

        let accumulator = StreamingAccumulator()
        // onChunk 是 @Sendable 闭包，用引用累加器收集，避免在并发闭包里改 var。
        let sink = StreamSink()
        for event in events {
            for chunk in try adapter.parseStreamChunks(data: Data(event.utf8)) {
                let keepGoing = await accumulator.consume(chunk) { piece in
                    sink.append(piece)
                }
                if !keepGoing { break }
            }
        }
        let response = try await accumulator.finish(model: "MiniMax-M3.1-Flash-Preview")

        #expect(response.content == "正文 A正文 B")
        #expect(response.reasoningContent == "思考 A思考 B")
        // 流式回调侧收到的内容与最终响应一致：思考与正文都没有被丢弃。
        #expect(sink.textOnly == "正文 A正文 B")
        #expect(sink.reasoning == "思考 A思考 B")
        // 正文非空即满足 AgentLoop 的空响应判定。
        #expect(!response.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test("仅思考无正文时仍产出思考事件，且不伪造正文")
    func openAIAdapterEmitsThinkingOnlyChunk() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(baseURL: "https://api.minimaxi.com/v1")
        )
        let event = """
        data: {"choices":[{"index":0,"delta":{"reasoning_content":"只有思考"}}],"model":"MiniMax-M3.1-Flash-Preview"}

        """
        let chunks = try adapter.parseStreamChunks(data: Data(event.utf8))

        #expect(chunks.count == 1)
        #expect(chunks.first?.eventType == .thinkingDelta)
        #expect(chunks.first?.content == "只有思考")
    }

    /// 正文与工具调用同 delta 时两者都保留。
    ///
    /// 早期实现用 `if chunks.isEmpty` 守卫，断言只有正文 chunk（tool_calls
    /// 被整包丢弃）。该取舍会让 interleaved thinking 模型（MiniMax M3 等）
    /// 在收敛帧丢掉工具调用，累积器 content 恒为空，最终被判为「模型返回空
    /// 响应」。字段键名互相独立、累加器分别写入，因此改为各自产出。
    @Test("正文与工具调用同 delta 时两者都保留")
    func openAIAdapterKeepsTextAndToolCallsInSameDelta() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(baseURL: "https://example.com")
        )
        let event = sseEvent([
            "choices": [
                [
                    "index": 0,
                    "delta": [
                        "content": "我先看看",
                        "tool_calls": [toolCallFixture()],
                    ],
                ],
            ],
        ])

        let chunks = try adapter.parseStreamChunks(data: Data(event.utf8))

        #expect(chunks.contains { $0.eventType == .textDelta && $0.content == "我先看看" })
        #expect(chunks.contains { $0.toolCalls?.first?.name == "read_file" })
    }

    @Test("带正文与 finish_reason 的 delta 同时保留正文与结束信号")
    func openAIAdapterKeepsContentWithFinishReason() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(baseURL: "https://example.com")
        )
        let event = """
        data: {"choices":[{"index":0,"delta":{"content":"收尾正文"},"finish_reason":"stop"}],"usage":{"prompt_tokens":9,"completion_tokens":3}}

        """
        let chunks = try adapter.parseStreamChunks(data: Data(event.utf8))

        #expect(chunks.count == 1)
        #expect(chunks.first?.eventType == .textDelta)
        #expect(chunks.first?.content == "收尾正文")
        #expect(chunks.first?.stopReason == "stop")
        #expect(chunks.first?.outputTokens == 3)
    }

    @Test("无任何增量的空 delta 不产出 chunk")
    func openAIAdapterSkipsEmptyDelta() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(baseURL: "https://example.com")
        )
        let event = "data: {\"id\":\"x\",\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\"}}],\"usage\":null}\n\n"

        let chunks = try adapter.parseStreamChunks(data: Data(event.utf8))

        #expect(chunks.isEmpty)
    }

    @Test("返回空 chunk 的网关配置保持既有行为")
    func openAIAdapterKeepsEmptyChunkFallback() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(
                baseURL: "https://example.com",
                returnsEmptyChunkWhenNoDelta: true
            )
        )
        let event = "data: {\"choices\":[{\"index\":0,\"delta\":{}}]}\n\n"

        let chunks = try adapter.parseStreamChunks(data: Data(event.utf8))

        #expect(chunks.count == 1)
        #expect(chunks.first?.eventType == .textDelta)
        #expect(chunks.first?.content == "")
    }

    @Test("工具调用事件仍产出可累积的 chunk")
    func openAIAdapterStillParsesToolCallDeltas() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(baseURL: "https://example.com")
        )
        let event = sseEvent([
            "choices": [
                [
                    "index": 0,
                    "delta": ["tool_calls": [toolCallFixture()]],
                ],
            ],
        ])

        let chunks = try adapter.parseStreamChunks(data: Data(event.utf8))

        #expect(chunks.count == 1)
        #expect(chunks.first?.toolCalls?.first?.name == "read_file")
    }

    @Test("[DONE] 事件产出终止 chunk")
    func openAIAdapterParsesDoneMarker() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(baseURL: "https://example.com")
        )

        let chunks = try adapter.parseStreamChunks(data: Data("data: [DONE]\n\n".utf8))

        #expect(chunks.count == 1)
        #expect(chunks.first?.isDone == true)
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

    @Test("OpenAI 兼容请求不会把工具图片放进 assistant 内容")
    func openAIAdapterMovesToolImagesToSyntheticUserMessage() throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(baseURL: "https://api.deepseek.com/v1")
        )
        let image = MessageImage(data: Data([0x89, 0x50, 0x4E, 0x47]), mimeType: "image/png")
        let messages = [
            LLMMessage(
                role: .assistant,
                content: "",
                toolCalls: [LLMToolCall(id: "read-image", name: "read_image", arguments: "{}")],
                // 防御历史错误状态：assistant 即使带有图片，也不能原样发出。
                images: [image]
            ),
            LLMMessage(
                role: .tool,
                content: "已读取图片",
                toolCallID: "read-image",
                images: [image]
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
        #expect(bodyMessages?[0]["role"] as? String == "assistant")
        #expect(bodyMessages?[0]["content"] as? String == "")
        #expect(bodyMessages?[1]["role"] as? String == "tool")
        #expect(bodyMessages?[1]["content"] as? String == "已读取图片")
        #expect(bodyMessages?[2]["role"] as? String == "user")
        let visualContent = bodyMessages?[2]["content"] as? [[String: Any]]
        #expect(visualContent?.contains { $0["type"] as? String == "image_url" } == true)
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

    @Test("测试进程忘记隔离 service 时重定向，不写生产 Keychain")
    func testProcessRedirectsProductionService() {
        let previousService = VendorAPIKeyTools.keychainService
        defer { VendorAPIKeyTools.keychainService = previousService }

        // 模拟「调用方忘了改 service」：仍为正式值。
        VendorAPIKeyTools.keychainService = "com.coffic.lumi.apikey"
        let redirected = VendorAPIKeyTools.effectiveService

        #expect(redirected != "com.coffic.lumi.apikey",
                "测试进程下必须重定向，否则会写进用户真实 Keychain")
        #expect(redirected.hasPrefix("com.coffic.lumi.apikey.xctest."))

        // 已自行隔离的调用方不受重定向，service 原样透传。
        VendorAPIKeyTools.keychainService = "com.kit.llm.test.custom"
        #expect(VendorAPIKeyTools.effectiveService == "com.kit.llm.test.custom")
    }

    @Test("完整 Keychain 查询遇到一次 not-found 后会重试并恢复 Key")
    func apiKeyReadRetriesCompleteMissingLookup() throws {
        var results: [String?] = [nil, "sk-recovered"]
        var delays: [UInt64] = []

        let value = try VendorAPIKeyTools.readWithMissingRetry(
            sleeper: { delays.append($0) },
            operation: { results.removeFirst() }
        )

        #expect(value == "sk-recovered")
        #expect(results.isEmpty)
        #expect(delays == [50_000_000])
    }

    @Test("连续完整查询均 not-found 后才认定 API Key 缺失")
    func apiKeyReadConfirmsMissingAcrossRetries() throws {
        var attempts = 0

        let value = try VendorAPIKeyTools.readWithMissingRetry(
            sleeper: { _ in },
            operation: {
                attempts += 1
                return nil
            }
        )

        #expect(value == nil)
        #expect(attempts == 3)
    }

    @Test("网络中断可重试但认证失败不可重试")
    func retryPolicyClassifiesTransientErrors() {
        let network = ProviderRetryPolicy.decision(
            forNetworkError: NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost),
            attempt: 1,
            maxAttempts: 3
        )
        #expect(network.shouldRetry)

        let tls = ProviderRetryPolicy.decision(
            forNetworkError: NSError(domain: NSURLErrorDomain, code: NSURLErrorSecureConnectionFailed),
            attempt: 1,
            maxAttempts: 3
        )
        #expect(tls.shouldRetry)

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
