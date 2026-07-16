import Foundation

/// 流式响应中工具调用的轻量表示（Kit 内部使用）
public struct KitToolCall: Sendable, Equatable {
    public let id: String
    public let name: String
    public let arguments: String

    public init(id: String, name: String, arguments: String) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

/// 流式响应聚合状态
public actor StreamingState {
    public var accumulatedContentChunks: [String] = []
    public var accumulatedContentLength: Int = 0
    public var accumulatedThinkingChunks: [String] = []
    public var accumulatedThinkingLength: Int = 0
    public var accumulatedToolCalls: [KitToolCall] = []
    public var streamError: String?
    public var httpStatusCode: Int?
    public var httpResponseHeaders: [String: String]?
    public var httpResponseBody: String?
    public var currentToolCallId: String?
    public var currentToolCallName: String?
    public var currentToolCallArgumentChunks: [String] = []
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var totalTokens: Int?
    public var stopReason: String?
    public var timeToFirstToken: Double?
    public var firstTokenTime: CFAbsoluteTime?
    public var isFirstToken = true
    public let startTime: CFAbsoluteTime

    /// 思考内容最大长度（由调用方注入，默认 100,000）
    public let maxThinkingLength: Int

    public init(startTime: CFAbsoluteTime, maxThinkingLength: Int = 100_000) {
        self.startTime = startTime
        self.maxThinkingLength = maxThinkingLength
    }

    @discardableResult
    public func recordFirstToken() -> Double? {
        guard isFirstToken else { return nil }
        isFirstToken = false
        let now = CFAbsoluteTimeGetCurrent()
        firstTokenTime = now
        let ttft = (now - startTime) * 1000.0
        timeToFirstToken = ttft
        return ttft
    }

    public func appendContent(_ content: String) {
        accumulatedContentChunks.append(content)
        accumulatedContentLength += content.count
    }

    public func appendThinking(_ content: String) {
        guard !content.isEmpty else { return }
        guard accumulatedThinkingLength < maxThinkingLength else { return }
        let remaining = maxThinkingLength - accumulatedThinkingLength
        let part = String(content.prefix(remaining))
        guard !part.isEmpty else { return }
        accumulatedThinkingChunks.append(part)
        accumulatedThinkingLength += part.count
    }

    public func startNewToolCall(id: String, name: String, hasPartialJson: Bool = false, arguments: String = "") {
        saveCurrentToolCall()
        currentToolCallId = id
        currentToolCallName = name
        if !hasPartialJson && !arguments.isEmpty && arguments != "{}" {
            currentToolCallArgumentChunks = [arguments]
        } else {
            currentToolCallArgumentChunks = []
        }
    }

    public func finalizeCurrentToolCall() -> KitToolCall? {
        guard let currentId = currentToolCallId,
              let currentName = currentToolCallName else {
            return nil
        }
        let arguments: String
        if currentToolCallArgumentChunks.isEmpty {
            arguments = "{}"
        } else if currentToolCallArgumentChunks.count == 1 {
            arguments = currentToolCallArgumentChunks[0]
        } else {
            arguments = currentToolCallArgumentChunks.joined()
        }
        return KitToolCall(id: currentId, name: currentName, arguments: arguments)
    }

    public func saveCurrentToolCall() {
        if let toolCall = finalizeCurrentToolCall() {
            accumulatedToolCalls.append(toolCall)
            currentToolCallId = nil
            currentToolCallName = nil
            currentToolCallArgumentChunks = []
        }
    }

    public func appendToolCallArguments(_ partialJson: String) {
        currentToolCallArgumentChunks.append(partialJson)
    }

    public func recordHttpResponse(statusCode: Int?, headers: [String: String]? = nil, body: String? = nil) {
        httpStatusCode = statusCode
        if let headers { httpResponseHeaders = headers }
        if let body { httpResponseBody = body }
    }

    public func setError(_ error: String) {
        streamError = error
    }

    public func updateTokens(input: Int?, output: Int?) {
        if let input = input { inputTokens = input }
        if let output = output { outputTokens = output }
        // 自动计算 totalTokens
        if let input = inputTokens, let output = outputTokens {
            totalTokens = input + output
        } else {
            totalTokens = nil
        }
    }

    public func setStopReason(_ reason: String) {
        stopReason = reason
    }

    /// 计算流式传输耗时（从第一个 token 到完成的时间）
    /// - Returns: 流式传输耗时（毫秒），如果没有第一个 token 则返回 nil
    public func getStreamingDuration() -> Double? {
        guard let firstTokenTime = firstTokenTime else { return nil }
        let now = CFAbsoluteTimeGetCurrent()
        return (now - firstTokenTime) * 1000.0
    }

    /// 获取最终的思考内容
    /// - Returns: 思考内容字符串，如果为空则返回 nil
    public func getFinalThinking() -> String? {
        let thinking = accumulatedThinkingChunks.joined()
        return thinking.isEmpty ? nil : thinking
    }

    /// 获取最终的工具调用列表
    /// - Returns: 工具调用数组，如果为空则返回 nil
    public func getFinalToolCalls() -> [KitToolCall]? {
        return accumulatedToolCalls.isEmpty ? nil : accumulatedToolCalls
    }
}
