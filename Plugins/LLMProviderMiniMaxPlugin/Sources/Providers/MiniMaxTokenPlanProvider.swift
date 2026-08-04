import Foundation
import LLMKit
import LumiKernel

enum MiniMaxProviderCatalog {
    static let models = ["MiniMax-M3", "MiniMax-M2.7", "MiniMax-M2.7-highspeed", "MiniMax-M2.5", "MiniMax-M2", "MiniMax-Text-01"]
    static let contexts = ["MiniMax-M3": 204_800, "MiniMax-M2.7": 204_800, "MiniMax-M2.7-highspeed": 204_800, "MiniMax-M2.5": 204_800, "MiniMax-M2": 131_072, "MiniMax-Text-01": 4_000_000]
    static let capabilities: [String: LumiModelCapabilities] = [
        "MiniMax-M3": .init(supportsVision: true, supportsTools: true), "MiniMax-M2.7": .init(supportsVision: true, supportsTools: true), "MiniMax-M2.7-highspeed": .init(supportsVision: true, supportsTools: true), "MiniMax-M2.5": .init(supportsVision: false, supportsTools: true), "MiniMax-M2": .init(supportsVision: false, supportsTools: true), "MiniMax-Text-01": .init(supportsVision: false, supportsTools: false),
    ]
}

class MiniMaxProviderSupport {
    static let apiKeyStorageKey = "DevAssistant_ApiKey_MiniMax"

    func resolveAPIKey(displayName: String) throws -> String { try LumiAPIKeyTools.resolve(storageKey: Self.apiKeyStorageKey, displayName: displayName) }
    func hasAPIKey() -> Bool { LumiAPIKeyTools.has(storageKey: Self.apiKeyStorageKey) }
    func getAPIKey() -> String { LumiAPIKeyTools.get(storageKey: Self.apiKeyStorageKey) }
    func setAPIKey(_ value: String) { LumiAPIKeyTools.set(value, storageKey: Self.apiKeyStorageKey) }
    func removeAPIKey() { LumiAPIKeyTools.remove(storageKey: Self.apiKeyStorageKey) }

    func errorKind(_ error: Error) -> String? {
        if case LumiLLMProviderSupportError.missingAPIKey = error { return MiniMaxRenderKind.apiKeyMissing }
        if let code = (error as? MiniMaxProviderError)?.statusCode { return MiniMaxRenderKind.http(code) }
        if let code = LumiLLMHTTPErrorParsing.statusCode(from: error) { return MiniMaxRenderKind.http(code) }
        return MiniMaxRenderKind.requestFailed
    }

    func errorMessage(providerID: String, conversationID: UUID, request: LumiLLMRequest, error: Error, disposition: LumiLLMErrorDisposition) -> LumiChatMessage {
        LumiLLMProviderErrorSupport.makeErrorMessage(providerID: providerID, conversationID: conversationID, request: request, error: error, disposition: disposition, renderKind: errorKind(error))
    }
}

public typealias MiniMaxTokenPlanProvider = MiniMaxOpenAIProvider

final class MiniMaxMessageState: @unchecked Sendable {
    private let lock = NSLock(); private var content = ""; private var reasoning = ""; private var calls: [LumiToolCall] = []; private var activeID: String?; private var activeName: String?; private var activeArgs = ""; private var error: String?; private var stopReason: String?; private var started: Date; private var first: Date?; private var ended: Date?; private let conversationID: UUID; private let providerID: String; private let model: String; private var input: Int?; private var output: Int?; private var thinkingParser = MiniMaxThinkingTagParser()
    init(conversationID: UUID, providerID: String, model: String, started: Date) { self.conversationID = conversationID; self.providerID = providerID; self.model = model; self.started = started }
    func setError(_ value: String) { lock.lock(); error = value; lock.unlock() }
    @discardableResult
    func append(_ event: MiniMaxOpenAIEvent) -> MiniMaxTextSegments { lock.lock(); defer { lock.unlock() }; var segments = event.content.map { thinkingParser.append($0) } ?? MiniMaxTextSegments(); if let value = event.reasoning, !value.isEmpty { segments.thinking += value }; if !segments.content.isEmpty || !segments.thinking.isEmpty, first == nil { first = Date() }; input = event.inputTokens ?? input; output = event.outputTokens ?? output; stopReason = event.stopReason ?? stopReason; for delta in event.toolDeltas { if delta.id != nil || delta.name != nil { saveToolLocked(); activeID = delta.id ?? UUID().uuidString; activeName = delta.name ?? ""; activeArgs = delta.arguments } else { activeArgs += delta.arguments } }; content += segments.content; reasoning += segments.thinking; return segments }
    func append(_ event: MiniMaxAnthropicEvent) { lock.lock(); defer { lock.unlock() }; if let value = event.text, !value.isEmpty { if first == nil { first = Date() }; content += value }; if let value = event.thinking, !value.isEmpty { if first == nil { first = Date() }; reasoning += value }; if let id = event.toolID { saveToolLocked(); activeID = id; activeName = event.toolName ?? "" }; if let args = event.toolArguments { activeArgs += args }; stopReason = event.stopReason ?? stopReason }
    @discardableResult
    func finish() -> MiniMaxTextSegments { lock.lock(); defer { lock.unlock() }; let segments = thinkingParser.finish(); if !segments.content.isEmpty { content += segments.content }; if !segments.thinking.isEmpty { reasoning += segments.thinking }; ended = Date(); saveToolLocked(); return segments }
    private func saveToolLocked() {
        guard let id = activeID, let name = activeName else { return }
        let arguments = activeArgs.isEmpty ? "{}" : MiniMaxToolArguments.normalized(activeArgs)
        calls.append(LumiToolCall(id: id, name: name, arguments: arguments))
        activeID = nil
        activeName = nil
        activeArgs = ""
    }
    func message() -> LumiChatMessage { lock.lock(); defer { lock.unlock() }; let end = ended ?? Date(); return LumiChatMessage(conversationID: conversationID, role: .assistant, content: content, providerID: providerID, modelName: model, rawErrorDetail: error, toolCalls: calls.isEmpty ? nil : calls, reasoningContent: reasoning.isEmpty ? nil : reasoning, inputTokenCount: input, outputTokenCount: output, latencyMs: end.timeIntervalSince(started) * 1000, timeToFirstTokenMs: first.map { $0.timeIntervalSince(started) * 1000 }, streamingDurationMs: first.map { end.timeIntervalSince($0) * 1000 }) }
}
