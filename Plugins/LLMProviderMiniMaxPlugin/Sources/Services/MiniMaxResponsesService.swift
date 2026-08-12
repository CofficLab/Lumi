import Foundation
import LumiKernel

// MARK: - Message State

final class MiniMaxResponsesMessageState: @unchecked Sendable {
    private let lock = NSLock()
    private var content = ""
    private var reasoning = ""
    private var calls: [LumiToolCall] = []
    private var activeCallID: String?
    private var activeCallName: String?
    private var activeCallArguments = ""
    private var error: String?
    private var stopReason: String?
    private var started: Date
    private var first: Date?
    private var ended: Date?
    private let conversationID: UUID
    private let providerID: String
    private let model: String
    private var inputTokens: Int?
    private var outputTokens: Int?
    private let toolNameMap: [String: String]

    init(conversationID: UUID, providerID: String, model: String, started: Date, toolNameMap: [String: String] = [:]) {
        self.conversationID = conversationID
        self.providerID = providerID
        self.model = model
        self.started = started
        self.toolNameMap = toolNameMap
    }

    func setError(_ value: String) {
        lock.lock(); error = value; lock.unlock()
    }

    func append(_ event: MiniMaxResponsesEvent) {
        lock.lock(); defer { lock.unlock() }

        if let text = event.text, !text.isEmpty {
            if first == nil { first = Date() }
            content += text
        }

        if let reasoning = event.reasoning, !reasoning.isEmpty {
            if first == nil { first = Date() }
            self.reasoning += reasoning
        }

        if event.type == .functionCall {
            if let callID = event.callID {
                saveCallLocked()
                activeCallID = callID
                activeCallName = event.name ?? ""
                activeCallArguments = event.arguments ?? ""
            } else {
                activeCallArguments += event.arguments ?? ""
            }
        }

        if let usage = event.usage {
            inputTokens = usage.inputTokens
            outputTokens = usage.outputTokens
        }

        if let stopReason = event.stopReason {
            self.stopReason = stopReason
        }
    }

    func finish() {
        lock.lock(); defer { lock.unlock() }
        ended = Date()
        saveCallLocked()
    }

    private func saveCallLocked() {
        guard let id = activeCallID, let name = activeCallName else { return }
        let arguments = activeCallArguments.isEmpty ? "{}" : normalizedArguments(activeCallArguments)
        // 模型回传的工具名是 sanitize 后的，按映射还原为 Lumi 注册 id，否则工具调度按原始 id 查找时会找不到。
        calls.append(LumiToolCall(id: id, name: toolNameMap[name] ?? name, arguments: arguments))
        activeCallID = nil
        activeCallName = nil
        activeCallArguments = ""
    }

    private func normalizedArguments(_ raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let normalizedData = try? JSONSerialization.data(withJSONObject: object),
              let normalized = String(data: normalizedData, encoding: .utf8) else {
            return raw
        }
        return normalized
    }

    func message() -> LumiChatMessage {
        lock.lock(); defer { lock.unlock() }
        let end = ended ?? Date()
        return LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: content,
            providerID: providerID,
            modelName: model,
            rawErrorDetail: error,
            toolCalls: calls.isEmpty ? nil : calls,
            reasoningContent: reasoning.isEmpty ? nil : reasoning,
            inputTokenCount: inputTokens,
            outputTokenCount: outputTokens,
            latencyMs: end.timeIntervalSince(started) * 1000,
            timeToFirstTokenMs: first.map { $0.timeIntervalSince(started) * 1000 },
            streamingDurationMs: first.map { end.timeIntervalSince($0) * 1000 }
        )
    }
}

// MARK: - HTTP Service

final class MiniMaxResponsesService: @unchecked Sendable {
    let url: URL
    private let network: (any NetworkProviding)?

    init(baseURL: String = "https://api.minimaxi.com/v1/responses", network: (any NetworkProviding)?) throws {
        guard let url = URL(string: baseURL) else {
            throw MiniMaxProviderError.invalidRequest("Invalid MiniMax Responses URL")
        }
        self.url = url
        self.network = network
    }

    func send(
        apiKey: String,
        body: Data,
        onEvent: @Sendable @escaping (MiniMaxResponsesEvent) async -> Bool
    ) async throws {
        guard let network else { throw MiniMaxProviderError.networkUnavailable }
        let parser = MiniMaxResponsesSSEParser()
        try await network.stream(
            HTTPRequest(url: url, method: .post, headers: [
                "Authorization": "Bearer \(apiKey)",
                "Content-Type": "application/json",
                "Accept": "text/event-stream",
            ], body: body, timeout: 300),
            onResponse: { _ in },
            onChunk: { data in
                for event in parser.append(data) {
                    if !(await onEvent(event)) { return false }
                }
                return true
            }
        )
        for event in parser.finish() {
            if !(await onEvent(event)) { break }
        }
    }
}

// MARK: - SSE Parser

final class MiniMaxResponsesSSEParser: @unchecked Sendable {
    private var buffer = ""

    func append(_ data: Data) -> [MiniMaxResponsesEvent] {
        buffer += String(decoding: data, as: UTF8.self)
        let frames = completeFrames()
        return frames.flatMap { MiniMaxResponsesEventParser.parse(Data($0.utf8)) }
    }

    func finish() -> [MiniMaxResponsesEvent] {
        let frame = buffer
        buffer.removeAll(keepingCapacity: true)
        guard !frame.isEmpty else { return [] }
        return MiniMaxResponsesEventParser.parse(Data(frame.utf8))
    }

    private func completeFrames() -> [String] {
        var frames: [String] = []
        while let range = buffer.range(of: "\n\n") {
            frames.append(String(buffer[..<range.upperBound]))
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
        }
        return frames
    }
}
