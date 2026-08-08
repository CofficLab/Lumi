import Foundation

struct KimiCodeEvent: Sendable {
    var content: String?
    var reasoning: String?
    var toolDeltas: [KimiCodeToolDelta]
    var stopReason: String?
    var done: Bool
    var error: String?
    var inputTokens: Int?
    var outputTokens: Int?
    var cacheHitTokens: Int?
    var cacheTotalInputTokens: Int?

    init(
        content: String? = nil,
        reasoning: String? = nil,
        toolDeltas: [KimiCodeToolDelta] = [],
        stopReason: String? = nil,
        done: Bool = false,
        error: String? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        cacheHitTokens: Int? = nil,
        cacheTotalInputTokens: Int? = nil
    ) {
        self.content = content
        self.reasoning = reasoning
        self.toolDeltas = toolDeltas
        self.stopReason = stopReason
        self.done = done
        self.error = error
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheHitTokens = cacheHitTokens
        self.cacheTotalInputTokens = cacheTotalInputTokens
    }
}