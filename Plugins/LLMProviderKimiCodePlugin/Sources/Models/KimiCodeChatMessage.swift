import Foundation
import KernelLumi

struct KimiCodeChatMessage: Sendable {
    static let thinkingSignatureKey = "thinkingSignature"

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
    var thinkingSignature: String?
    var toolCalls: [LumiToolCall]?
    var stopReason: String?
    var outputTokenCount: Int?
    var inputTokenCount: Int?
    var cachedInputTokens: Int?
    var cacheTotalInputTokens: Int?

    var latencyMs: Double?
    var timeToFirstTokenMs: Double?
    var streamingDurationMs: Double?

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
        thinkingSignature: String? = nil,
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
        self.thinkingSignature = thinkingSignature
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
            modelName: modelName
        )
        message.requestStartedAt = requestStartedAt
        message.streamingStartedAt = streamingStartedAt
        return message
    }

    mutating func merge(_ event: KimiCodeEvent, now: Date = Date()) {
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

    mutating func finalize(now: Date = Date()) {
        if let start = streamingStartedAt {
            streamingDurationMs = now.timeIntervalSince(start) * 1000.0
        }
        if let start = requestStartedAt {
            latencyMs = now.timeIntervalSince(start) * 1000.0
        }
    }

    mutating func mergeTextDelta(_ value: String, now: Date = Date()) {
        guard !value.isEmpty else { return }
        if streamingStartedAt == nil { streamingStartedAt = now }
        recordFirstTokenIfNeeded(now: now)
        content += value
    }

    mutating func mergeThinkingDelta(_ value: String, now: Date = Date()) {
        guard !value.isEmpty else { return }
        if streamingStartedAt == nil { streamingStartedAt = now }
        recordFirstTokenIfNeeded(now: now)
        if reasoningContent == nil { reasoningContent = "" }
        reasoningContent? += value
    }

    mutating func beginToolCall(id: String, name: String) {
        if toolCalls == nil { toolCalls = [] }
        toolCalls?.append(LumiToolCall(id: id, name: name, arguments: ""))
    }

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

    mutating func setStopReason(_ value: String) {
        guard !value.isEmpty else { return }
        stopReason = value
    }

    var hitMaxTokensWithoutOutput: Bool {
        guard stopReason == "max_tokens" || stopReason == "length" else { return false }
        return content.isEmpty && (toolCalls?.isEmpty ?? true)
    }

    mutating func mergeUsage(_ usage: KimiCodeAnthropicUsage) {
        if let input = usage.inputTokens { inputTokenCount = input }
        if let output = usage.outputTokens { outputTokenCount = output }
        if let cached = usage.cacheReadInputTokens {
            cachedInputTokens = cached
            if let input = usage.inputTokens {
                cacheTotalInputTokens = input + cached + (usage.cacheCreationInputTokens ?? 0)
            }
        }
    }

    func toLumiChatMessage() -> LumiChatMessage {
        var metadata = metadata
        if let stopReason, metadata["stopReason"] == nil {
            metadata["stopReason"] = stopReason
        }
        if let thinkingSignature, metadata[Self.thinkingSignatureKey] == nil {
            metadata[Self.thinkingSignatureKey] = thinkingSignature
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

    private mutating func recordFirstTokenIfNeeded(now: Date) {
        guard firstTokenAt == nil else { return }
        firstTokenAt = now
        if let start = requestStartedAt {
            timeToFirstTokenMs = now.timeIntervalSince(start) * 1000.0
        }
    }

    private mutating func apply(toolDeltas: [KimiCodeToolDelta]) {
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

final class KimiCodeChatMessageCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var message: KimiCodeChatMessage

    init(message: KimiCodeChatMessage) {
        self.message = message
    }

    func mutate(_ block: (inout KimiCodeChatMessage) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        block(&message)
    }

    func snapshot() -> KimiCodeChatMessage {
        lock.lock()
        defer { lock.unlock() }
        return message
    }
}