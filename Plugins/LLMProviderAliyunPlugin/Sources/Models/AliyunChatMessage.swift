import Foundation
import KernelLumi

/// 阿里云侧聊天消息结构。
struct AliyunChatMessage: Sendable {
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

    var content: String
    var reasoningContent: String?
    var toolCalls: [LumiToolCall]?
    var stopReason: String?
    var outputTokenCount: Int?
    var inputTokenCount: Int?
    var cachedInputTokens: Int?
    var cacheCreationTokens: Int?

    var latencyMs: Double?
    var timeToFirstTokenMs: Double?
    var streamingDurationMs: Double?

    /// 「sanitize 后名字 → 原始注册名」映射(解析期临时状态)。由 provider 在发起请求时
    /// 注入,用于把模型回传的 sanitized 工具名(点号被替换成下划线)还原成注册名。
    /// 不会被 `toLumiChatMessage` 带出。
    var toolNameMap: [String: String]?

    fileprivate var firstTokenAt: Date?
    fileprivate var streamingStartedAt: Date?
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
        cacheCreationTokens: Int? = nil,
        latencyMs: Double? = nil,
        timeToFirstTokenMs: Double? = nil,
        streamingDurationMs: Double? = nil,
        toolNameMap: [String: String]? = nil
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
        self.cacheCreationTokens = cacheCreationTokens
        self.latencyMs = latencyMs
        self.timeToFirstTokenMs = timeToFirstTokenMs
        self.streamingDurationMs = streamingDurationMs
        self.toolNameMap = toolNameMap
        self.firstTokenAt = nil
        self.streamingStartedAt = nil
        self.requestStartedAt = nil
    }

    static func assembling(
        conversationID: UUID,
        providerID: String,
        modelName: String,
        requestStartedAt: Date = Date(),
        now: Date = Date(),
        toolNameMap: [String: String]? = nil
    ) -> Self {
        var message = Self(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: now,
            providerID: providerID,
            modelName: modelName,
            metadata: [:],
            toolNameMap: toolNameMap
        )
        message.requestStartedAt = requestStartedAt
        return message
    }

    // MARK: - 增量合并

    mutating func merge(_ event: AliyunAnthropicEvent, now: Date = Date()) {
        if streamingStartedAt == nil && (event.textDelta?.isEmpty == false || event.thinkingDelta?.isEmpty == false) {
            streamingStartedAt = now
        }

        if let value = event.textDelta, !value.isEmpty {
            recordFirstTokenIfNeeded(now: now)
            content += value
        }
        if let value = event.thinkingDelta, !value.isEmpty {
            recordFirstTokenIfNeeded(now: now)
            if reasoningContent == nil { reasoningContent = "" }
            reasoningContent? += value
        }
        if let value = event.toolInputJSONDelta, !value.isEmpty {
            appendToolArguments(value)
        }
        if let name = event.toolName, let id = event.toolID {
            beginToolCall(id: id, name: name)
        }
        if let value = event.stopReason, !value.isEmpty {
            stopReason = value
        }
        if let usage = event.usage {
            if let v = usage.inputTokens { inputTokenCount = v }
            if let v = usage.outputTokens { outputTokenCount = v }
            if let v = usage.cacheReadInputTokens { cachedInputTokens = v }
            if let v = usage.cacheCreationInputTokens { cacheCreationTokens = v }
        }
    }

    mutating func finalize(now: Date = Date()) {
        if let start = streamingStartedAt {
            streamingDurationMs = now.timeIntervalSince(start) * 1000.0
        }
        if let start = requestStartedAt {
            latencyMs = now.timeIntervalSince(start) * 1000.0
        }
    }

    fileprivate mutating func recordFirstTokenIfNeeded(now: Date) {
        if firstTokenAt == nil {
            firstTokenAt = now
            if let start = requestStartedAt {
                timeToFirstTokenMs = now.timeIntervalSince(start) * 1000.0
            }
        }
    }

    private mutating func beginToolCall(id: String, name: String) {
        if toolCalls == nil { toolCalls = [] }
        // 模型回传的是 sanitized 名(点号被替换成下划线),按映射表还原成注册名,
        // 否则 ToolManagerService 会因名字不一致而报 "Tool not found"。
        let restoredName = toolNameMap?[name] ?? name
        toolCalls?.append(LumiToolCall(id: id, name: restoredName, arguments: ""))
    }

    private mutating func appendToolArguments(_ json: String) {
        guard !json.isEmpty, var calls = toolCalls, !calls.isEmpty else { return }
        let lastIndex = calls.count - 1
        let last = calls[lastIndex]
        calls[lastIndex] = LumiToolCall(
            id: last.id,
            name: last.name,
            arguments: last.arguments + json,
            result: last.result,
            displayDescription: last.displayDescription
        )
        toolCalls = calls
    }

    var hitMaxTokensWithoutOutput: Bool {
        (stopReason == "max_tokens" || stopReason == "length") && content.isEmpty && (toolCalls?.isEmpty ?? true)
    }

    func toLumiChatMessage() -> LumiChatMessage {
        var metadata = self.metadata
        if let stopReason = stopReason {
            metadata["stopReason"] = stopReason
        }
        if let inputTokens = inputTokenCount {
            metadata["prompt_tokens"] = String(inputTokens)
        }
        if let outputTokens = outputTokenCount {
            metadata["completion_tokens"] = String(outputTokens)
        }
        if let cached = cachedInputTokens {
            metadata["cache_read_input_tokens"] = String(cached)
        }
        if let creation = cacheCreationTokens {
            metadata["cache_creation_input_tokens"] = String(creation)
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
            latencyMs: latencyMs,
            timeToFirstTokenMs: timeToFirstTokenMs,
            streamingDurationMs: streamingDurationMs
        )
    }
}

// MARK: - Collector

final class AliyunChatMessageCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var message: AliyunChatMessage

    init(message: AliyunChatMessage) {
        self.message = message
    }

    func mutate(_ body: (inout AliyunChatMessage) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        body(&message)
    }

    func snapshot() -> AliyunChatMessage {
        lock.lock()
        defer { lock.unlock() }
        return message
    }
}
