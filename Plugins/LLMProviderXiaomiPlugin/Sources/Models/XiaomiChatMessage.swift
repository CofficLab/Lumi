import Foundation
import LumiKernel

/// Xiaomi 侧的聊天消息结构.
///
/// 字段分两层：
/// - **协议字段**：来自 Xiaomi API 响应——
///   `content`、`toolCalls`、`stopReason`、
///   `inputTokenCount`、`outputTokenCount`。
/// - **本地派生字段**：在 `XiaomiProvider.sendStreaming` 中组装时填充——
///   `id`、`conversationID`、`role`、`turnID`、`createdAt`、
///   `providerID`、`modelName`、`isError`、`rawErrorDetail`、`renderKind`、
///   `metadata`、`toolCallID`、`latencyMs`、`timeToFirstTokenMs`、`streamingDurationMs`。
///
/// 组装流程：
/// 1. `assembling(conversationID:providerID:modelName:)` 创建一个空消息
/// 2. 每个 `XiaomiEvent` 进来调用 `merge(_:firstTokenAt:now:)`
/// 3. 流结束时调用 `finalize(now:)` 把 timing 写入
/// 4. 最后 `toLumiChatMessage()` 转成内核类型
struct XiaomiChatMessage: Sendable {
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
    /// 来自 `delta.tool_calls` 的最终结构化结果。
    var toolCalls: [LumiToolCall]?
    /// 来自 `choice.finish_reason`。
    var stopReason: String?
    /// 来自 `usage.completion_tokens`（本侧）。
    var outputTokenCount: Int?
    /// 来自 `usage.prompt_tokens`（输入侧）。
    var inputTokenCount: Int?

    // MARK: - 计时字段

    /// 请求开始 → 最后响应的整体耗时（毫秒）。
    var latencyMs: Double?
    /// 请求开始 → 首个内容 token 的耗时（毫秒）。
    var timeToFirstTokenMs: Double?
    /// 流开始 → 流结束的耗时（毫秒）。
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
        inputTokenCount: Int? = nil,
        outputTokenCount: Int? = nil,
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
        self.inputTokenCount = inputTokenCount
        self.outputTokenCount = outputTokenCount
        self.latencyMs = latencyMs
        self.timeToFirstTokenMs = timeToFirstTokenMs
        self.streamingDurationMs = streamingDurationMs
        self.firstTokenAt = nil
        self.streamingStartedAt = nil
        self.requestStartedAt = nil
    }

    // MARK: - 组装工厂

    /// 创建一个用于在 `sendStreaming` 中增量组装的助手消息。
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

    /// 把单个 `XiaomiEvent` 合并进当前消息。
    mutating func merge(
        _ event: XiaomiEvent,
        now: Date = Date()
    ) {
        let hasPayload = event.content?.isEmpty == false
        if hasPayload, streamingStartedAt == nil {
            streamingStartedAt = now
        }
        if let value = event.content, !value.isEmpty {
            recordFirstTokenIfNeeded(now: now)
            content += value
        }
        if !event.toolDeltas.isEmpty {
            apply(toolDeltas: event.toolDeltas)
        }
        if let value = event.stopReason, !value.isEmpty {
            stopReason = value
        }
        if let value = event.inputTokens { inputTokenCount = value }
        if let value = event.outputTokens { outputTokenCount = value }
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

    /// 把累积结果转成内核统一消息。
    func toLumiChatMessage() -> LumiChatMessage {
        var metadata = metadata
        if let stopReason, metadata["stopReason"] == nil {
            metadata["stopReason"] = stopReason
        }
        let usage = MessageTokenMetadata.metadata(
            inputTokens: inputTokenCount,
            outputTokens: outputTokenCount,
            cachedInputTokens: nil,
            cacheWriteInputTokens: nil,
            cacheTotalInputTokens: nil
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
            reasoningContent: nil,
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

    private mutating func apply(toolDeltas: [XiaomiToolDelta]) {
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

/// 用于在 `@Sendable` 异步闭包中安全 mutate `XiaomiChatMessage` 的线程安全容器。
final class XiaomiChatMessageCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var message: XiaomiChatMessage

    init(message: XiaomiChatMessage) {
        self.message = message
    }

    /// 在锁保护下 mutate 消息。
    func mutate(_ block: (inout XiaomiChatMessage) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        block(&message)
    }

    /// 取出当前累积结果（拷贝快照）。
    func snapshot() -> XiaomiChatMessage {
        lock.lock()
        defer { lock.unlock() }
        return message
    }
}
