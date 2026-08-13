import Foundation
import KernelLumi

/// StepFun 侧的聊天消息结构。
///
/// 字段分两层：
/// - **协议字段**：来自 StepFun API 响应——`content`、`toolCalls`、`stopReason`、
///   `inputTokenCount`、`outputTokenCount`。
/// - **本地派生字段**：在 `StepFunProvider.sendStreaming` 中组装时填充——
///   `id`、`conversationID`、`role`、`turnID`、`createdAt`、
///   `providerID`、`modelName`、`isError`、`rawErrorDetail`、`renderKind`、
///   `metadata`、`toolCallID`、`latencyMs`、`timeToFirstTokenMs`、`streamingDurationMs`。
///
/// 组装流程：
/// 1. `assembling(conversationID:providerID:modelName:)` 创建一个空消息
/// 2. 每个 `StepFunEvent` 进来调用 `merge(_:now:)`
/// 3. 流结束时调用 `finalize(now:)` 把 timing 写入
/// 4. 最后 `toLumiChatMessage()` 转成内核类型
struct StepFunChatMessage: Sendable {
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
    /// 来自 `usage.prompt_tokens`。
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

    /// 把单个 `StepFunEvent` 合并进当前消息。
    ///
    /// 合并语义：
    /// - 首次出现非空 `content` 时，自动设置 `streamingStartedAt` 并计算 `timeToFirstTokenMs`
    /// - `content`：累加
    /// - `toolDeltas`：调用 `apply(toolDeltas:)` 折叠到 `toolCalls`
    /// - `stopReason`：取最后一个非空值
    /// - usage：取最后一个非空值
    mutating func merge(
        _ event: StepFunEvent,
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
        if let value = event.outputTokens { outputTokenCount = value }
        if let value = event.inputTokens { inputTokenCount = value }
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

    // MARK: - 内部辅助

    fileprivate mutating func recordFirstTokenIfNeeded(now: Date) {
        if firstTokenAt == nil {
            firstTokenAt = now
            if let start = requestStartedAt {
                timeToFirstTokenMs = now.timeIntervalSince(start) * 1000.0
            }
        }
    }

    /// 把 `StepFunToolDelta` 数组折叠到 `toolCalls`。
    private mutating func apply(toolDeltas: [StepFunToolDelta]) {
        for delta in toolDeltas {
            if let id = delta.id, let name = delta.name {
                // 新工具调用开始
                if toolCalls == nil { toolCalls = [] }
                toolCalls?.append(LumiToolCall(id: id, name: name, arguments: ""))
            }
            // 累加 arguments 到最后一个工具调用
            if !delta.arguments.isEmpty, var calls = toolCalls, !calls.isEmpty {
                let lastIndex = calls.count - 1
                let last = calls[lastIndex]
                calls[lastIndex] = LumiToolCall(
                    id: last.id,
                    name: last.name,
                    arguments: last.arguments + delta.arguments,
                    result: last.result,
                    displayDescription: last.displayDescription
                )
                toolCalls = calls
            }
        }
    }

    // MARK: - 检测

    /// 检测是否撞上 max_tokens 上限且没有任何可见输出。
    var hitMaxTokensWithoutOutput: Bool {
        (stopReason == "max_tokens" || stopReason == "length") && content.isEmpty && (toolCalls?.isEmpty ?? true)
    }

    // MARK: - 转换

    /// 转成内核类型。
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
            latencyMs: latencyMs,
            timeToFirstTokenMs: timeToFirstTokenMs,
            streamingDurationMs: streamingDurationMs
        )
    }
}

// MARK: - 线程安全的 Collector

/// 使用 NSLock 保证线程安全的 `StepFunChatMessage` 包装器。
/// 解决 Swift 6 严格并发下 `mutation of captured var` 问题。
final class StepFunChatMessageCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var message: StepFunChatMessage

    init(message: StepFunChatMessage) {
        self.message = message
    }

    /// 在持有锁的情况下执行 mutation。
    func mutate(_ body: (inout StepFunChatMessage) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        body(&message)
    }

    /// 返回当前消息的快照。
    func snapshot() -> StepFunChatMessage {
        lock.lock()
        defer { lock.unlock() }
        return message
    }
}