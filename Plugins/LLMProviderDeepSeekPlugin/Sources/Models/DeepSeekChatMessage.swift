import Foundation
import LumiKernel

/// DeepSeek 侧的聊天消息结构。
///
/// 字段分两层：
/// - **协议字段**：来自 DeepSeek（OpenAI 兼容）API 响应——
///   `content`、`reasoningContent`、`toolCalls`、`stopReason`、
///   `inputTokenCount`、`outputTokenCount`、`cachedInputTokens`、`cacheTotalInputTokens`。
/// - **本地派生字段**：在 `DeepSeekOpenAIProvider.sendStreaming` 中组装时填充——
///   `id`、`conversationID`、`role`、`turnID`、`createdAt`、
///   `providerID`、`modelName`、`isError`、`rawErrorDetail`、`renderKind`、
///   `metadata`、`toolCallID`、`latencyMs`、`timeToFirstTokenMs`、`streamingDurationMs`。
///
/// 组装流程：
/// 1. `assembling(conversationID:providerID:modelName:)` 创建一个空消息
/// 2. 每个 `DeepSeekEvent` 进来调用 `merge(_:firstTokenAt:now:)`
/// 3. 流结束时调用 `finalize(now:)` 把 timing 写入
/// 4. 最后 `toLumiChatMessage()` 转成内核类型
struct DeepSeekChatMessage: Sendable {
    // MARK: - 本地派生字段

    let id: UUID
    let conversationID: UUID
    var role: LumiChatMessageRole
    var turnID: UUID?
    let createdAt: Date
    var providerID: String?
    var modelName: String?
    var isError: Bool
    var rawErrorDetail: String?
    var renderKind: String?
    var metadata: [String: String]
    var toolCallID: String?

    // MARK: - 协议字段

    /// 来自 `delta.content` 的累加。
    var content: String
    /// 来自 `delta.reasoning_content` 的累加。
    var reasoningContent: String?
    /// 来自 `delta.tool_calls` 的最终结构化结果。
    var toolCalls: [LumiToolCall]?
    /// 来自 `choice.finish_reason`。
    var stopReason: String?
    /// 来自 `usage.completion_tokens`（本侧）。
    var outputTokenCount: Int?
    /// 来自 `usage.prompt_tokens`（或 `prompt_cache_hit_tokens + prompt_cache_miss_tokens`）。
    var inputTokenCount: Int?
    /// 来自 `usage.prompt_cache_hit_tokens`。
    var cachedInputTokens: Int?
    /// 输入侧总 token（与 `inputTokenCount` 同源，单独保留以便与 `cached` 联动）。
    var cacheTotalInputTokens: Int?

    // MARK: - 计时字段

    /// 请求开始 → 最后响应的整体耗时（毫秒）。
    var latencyMs: Double?
    /// 请求开始 → 首个内容 token 的耗时（毫秒）。
    var timeToFirstTokenMs: Double?
    /// 流开始 → 流结束的耗时（毫秒）。`timeToFirstTokenMs` 与 `streamingDurationMs` 之和≈`latencyMs`。
    var streamingDurationMs: Double?

    // MARK: - 组装内部状态

    /// 是否已经记录过首个内容 token（用于 `timeToFirstTokenMs`）。
    fileprivate var firstTokenAt: Date?
    /// 流开始时间（用于 `streamingDurationMs`）。
    fileprivate var streamingStartedAt: Date?
    /// 请求开始时间（用于 `latencyMs`）。
    fileprivate var requestStartedAt: Date?

    init(
        id: UUID = UUID(),
        conversationID: UUID,
        role: LumiChatMessageRole,
        content: String,
        turnID: UUID? = nil,
        createdAt: Date = Date(),
        providerID: String? = nil,
        modelName: String? = nil,
        isError: Bool = false,
        rawErrorDetail: String? = nil,
        renderKind: String? = nil,
        metadata: [String: String] = [:],
        toolCalls: [LumiToolCall]? = nil,
        toolCallID: String? = nil,
        reasoningContent: String? = nil,
        inputTokenCount: Int? = nil,
        outputTokenCount: Int? = nil,
        cachedInputTokens: Int? = nil,
        cacheTotalInputTokens: Int? = nil,
        latencyMs: Double? = nil,
        timeToFirstTokenMs: Double? = nil,
        streamingDurationMs: Double? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.role = role
        self.content = content
        self.turnID = turnID
        self.createdAt = createdAt
        self.providerID = providerID
        self.modelName = modelName
        self.isError = isError
        self.rawErrorDetail = rawErrorDetail
        self.renderKind = renderKind
        self.metadata = metadata
        self.toolCalls = toolCalls
        self.toolCallID = toolCallID
        self.reasoningContent = reasoningContent
        self.inputTokenCount = inputTokenCount
        self.outputTokenCount = outputTokenCount
        self.cachedInputTokens = cachedInputTokens
        self.cacheTotalInputTokens = cacheTotalInputTokens
        self.latencyMs = latencyMs
        self.timeToFirstTokenMs = timeToFirstTokenMs
        self.streamingDurationMs = streamingDurationMs
        self.firstTokenAt = nil
        self.streamingStartedAt = nil
        self.requestStartedAt = nil
    }

    // MARK: - 组装工厂

    /// 创建一个用于在 `sendStreaming` 中增量组装的助手消息。
    ///
    /// - Parameters:
    ///   - conversationID: 会话 ID（来自首个请求消息）
    ///   - providerID: 固定写 `DeepSeekOpenAIProvider.info.id`
    ///   - modelName: 来自 `LumiLLMRequest.model`
    ///   - requestStartedAt: 请求开始时间，用于计算 `latencyMs`
    ///   - streamingStartedAt: 首个 SSE chunk 到达的时间，用于计算 `streamingDurationMs`
    ///   - now: 当前时间（注入便于测试）
    static func assembling(
        conversationID: UUID,
        providerID: String,
        modelName: String,
        requestStartedAt: Date = Date(),
        streamingStartedAt: Date? = nil,
        now: Date = Date()
    ) -> Self {
        var message = Self(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: now,
            providerID: providerID,
            modelName: modelName,
            metadata: [:]
        )
        message.requestStartedAt = requestStartedAt
        message.streamingStartedAt = streamingStartedAt
        return message
    }

    // MARK: - 增量合并

    /// 把单个 `DeepSeekEvent` 合并进当前消息。
    ///
    /// 合并语义：
    /// - 首次出现非空 `content`/`reasoningContent` 时，自动设置
    ///   `streamingStartedAt` 并据此计算 `timeToFirstTokenMs`
    /// - `content` / `reasoningContent`：累加
    /// - `toolDeltas`：调用 `apply(toolDeltas:)` 折叠到 `toolCalls`
    /// - `stopReason`：取最后一个非空值
    /// - usage：取最后一个非空值
    mutating func merge(
        _ event: DeepSeekEvent,
        now: Date = Date()
    ) {
        let hasPayload = (event.content?.isEmpty == false) || (event.reasoning?.isEmpty == false)
        if hasPayload, streamingStartedAt == nil {
            streamingStartedAt = now
        }
        if let value = event.content, !value.isEmpty {
            recordFirstTokenIfNeeded(now: now)
            content += value
        }
        if let value = event.reasoning, !value.isEmpty {
            recordFirstTokenIfNeeded(now: now)
            if reasoningContent == nil { reasoningContent = "" }
            reasoningContent? += value
        }
        if !event.toolDeltas.isEmpty {
            apply(toolDeltas: event.toolDeltas)
        }
        if let value = event.stopReason, !value.isEmpty {
            stopReason = value
        }
        if let value = event.outputTokens { outputTokenCount = value }
        if let value = event.inputTokens { inputTokenCount = value }
        if let value = event.cacheHitTokens { cachedInputTokens = value }
        if let value = event.cacheTotalInputTokens { cacheTotalInputTokens = value }
    }

    /// 流结束时调用，把 `streamingDurationMs` / `latencyMs` 写入。
    mutating func finalize(now: Date = Date()) {
        if let start = streamingStartedAt {
            streamingDurationMs = now.timeIntervalSince(start) * 1000.0
        }
        if let start = requestStartedAt {
            latencyMs = now.timeIntervalSince(start) * 1000.0
        }
    }

    // MARK: - 细粒度合并入口（Anthropic 协议等非 OpenAI 事件流使用）

    /// 累加文本增量（Anthropic `content_block_delta(type=text_delta)`）。
    ///
    /// 顺带负责首次文本时设置 `streamingStartedAt` 与 `timeToFirstTokenMs`。
    mutating func mergeTextDelta(_ value: String, now: Date = Date()) {
        guard !value.isEmpty else { return }
        if streamingStartedAt == nil { streamingStartedAt = now }
        recordFirstTokenIfNeeded(now: now)
        content += value
    }

    /// 累加思考增量（Anthropic `content_block_delta(type=thinking_delta)`）。
    mutating func mergeThinkingDelta(_ value: String, now: Date = Date()) {
        guard !value.isEmpty else { return }
        if streamingStartedAt == nil { streamingStartedAt = now }
        recordFirstTokenIfNeeded(now: now)
        if reasoningContent == nil { reasoningContent = "" }
        reasoningContent? += value
    }

    /// 开始一个新工具调用（Anthropic `content_block_start(type=tool_use)`）。
    mutating func beginToolCall(id: String, name: String) {
        if toolCalls == nil { toolCalls = [] }
        toolCalls?.append(LumiToolCall(id: id, name: name, arguments: ""))
    }

    /// 累加最后一个工具调用的 JSON 入参（Anthropic `content_block_delta(type=input_json_delta)`）。
    mutating func appendToolArguments(_ json: String) {
        guard !json.isEmpty, var calls = toolCalls, !calls.isEmpty else { return }
        let last = calls[calls.count - 1]
        let merged = LumiToolCall(
            id: last.id,
            name: last.name,
            arguments: last.arguments + json,
            result: last.result,
            displayDescription: last.displayDescription
        )
        calls[calls.count - 1] = merged
        toolCalls = calls
    }

    /// 设置 `stopReason`（Anthropic `message_delta.delta.stop_reason`）。
    mutating func setStopReason(_ value: String) {
        guard !value.isEmpty else { return }
        stopReason = value
    }

    /// 合并 Anthropic usage（`message_start` / `message_delta` 中的 usage 字段）。
    ///
    /// Anthropic 协议里 `input_tokens` / `output_tokens` 是分阶段给出的：
    /// - `message_start.message.usage` 通常仅含 `input_tokens`
    /// - `message_delta.usage` 通常仅含 `output_tokens`
    ///
    /// 因此两个字段独立累加（用最后一个非空值覆盖）。
    /// `cacheTotalInputTokens` 在 Anthropic 协议下无独立字段——`input_tokens`
    /// 本身已包含缓存命中(`cache_read`)与写入(`cache_creation`)部分，直接
    /// 用它作为缓存率分母，保证 UI 的 cache % 口径正确。
    mutating func mergeUsage(_ usage: DeepSeekAnthropicUsage) {
        if let input = usage.inputTokens {
            inputTokenCount = input
            cacheTotalInputTokens = input
        }
        if let output = usage.outputTokens { outputTokenCount = output }
        if let cached = usage.cacheReadInputTokens { cachedInputTokens = cached }
    }

    /// 把累积结果转成内核统一消息。
    ///
    /// - 把 `stopReason` 投影进 `metadata["stopReason"]`
    /// - 把 `cachedInputTokens` / `cacheTotalInputTokens` 投影进内核约定的 metadata key
    /// - 把 `inputTokenCount` / `outputTokenCount` 用 `MessageTokenMetadata.metadata(...)` 拼入
    /// - 已有 `metadata` 中的同名 key 优先保留（避免覆盖上层填入的值）
    func toLumiChatMessage() -> LumiChatMessage {
        var metadata = metadata
        if let stopReason, metadata["stopReason"] == nil {
            metadata["stopReason"] = stopReason
        }
        let usage = MessageTokenMetadata.metadata(
            inputTokens: inputTokenCount,
            outputTokens: outputTokenCount,
            cachedInputTokens: cachedInputTokens,
            cacheWriteInputTokens: nil,
            cacheTotalInputTokens: cacheTotalInputTokens
        )
        for (key, value) in usage where metadata[key] == nil {
            metadata[key] = value
        }
        return LumiChatMessage(
            id: id,
            conversationID: conversationID,
            role: role,
            content: content,
            turnID: turnID,
            createdAt: createdAt,
            providerID: providerID,
            modelName: modelName,
            isError: isError,
            rawErrorDetail: rawErrorDetail,
            renderKind: renderKind,
            metadata: metadata,
            toolCalls: toolCalls,
            toolCallID: toolCallID,
            reasoningContent: reasoningContent,
            inputTokenCount: inputTokenCount,
            outputTokenCount: outputTokenCount,
            latencyMs: latencyMs,
            timeToFirstTokenMs: timeToFirstTokenMs,
            streamingDurationMs: streamingDurationMs
        )
    }

    // MARK: - 私有

    private mutating func recordFirstTokenIfNeeded(now: Date) {
        guard firstTokenAt == nil else { return }
        firstTokenAt = now
        if let start = requestStartedAt {
            timeToFirstTokenMs = now.timeIntervalSince(start) * 1000.0
        }
    }

    private mutating func apply(toolDeltas: [DeepSeekToolDelta]) {
        guard !toolDeltas.isEmpty else { return }
        if toolCalls == nil { toolCalls = [] }
        for delta in toolDeltas {
            if delta.id != nil || delta.name != nil {
                let id = delta.id ?? UUID().uuidString
                let name = delta.name ?? ""
                let args = delta.arguments.isEmpty ? "{}" : delta.arguments
                toolCalls?.append(LumiToolCall(id: id, name: name, arguments: args))
            } else if var calls = toolCalls, !calls.isEmpty {
                let last = calls[calls.count - 1]
                let merged = LumiToolCall(
                    id: last.id,
                    name: last.name,
                    arguments: last.arguments + delta.arguments,
                    result: last.result,
                    displayDescription: last.displayDescription
                )
                calls[calls.count - 1] = merged
                toolCalls = calls
            }
        }
    }
}

// MARK: - 跨并发闭包使用的可收集容器

/// 用于在 `@Sendable` 异步闭包中安全 mutate `DeepSeekChatMessage` 的线程安全容器。
///
/// `DeepSeekChatMessage` 本身是值类型，但 `sendStreaming` 把 `var message` 捕获到
/// `apiService.send(...)` 的闭包里时会触发 Swift 6 严格并发的
/// `mutation of captured var '...' in concurrently-executing code` 错误。
/// 这个容器用 `NSLock` 把 mutate 串行化，让闭包可以原地合并事件。
final class DeepSeekChatMessageCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var message: DeepSeekChatMessage

    init(message: DeepSeekChatMessage) {
        self.message = message
    }

    /// 在锁保护下 mutate 消息。
    func mutate(_ block: (inout DeepSeekChatMessage) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        block(&message)
    }

    /// 取出当前累积结果（拷贝快照）。
    func snapshot() -> DeepSeekChatMessage {
        lock.lock()
        defer { lock.unlock() }
        return message
    }
}