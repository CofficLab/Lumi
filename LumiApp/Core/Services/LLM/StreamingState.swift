import Foundation

/// 流式响应聚合状态
actor StreamingState {
    var accumulatedContentChunks: [String] = []
    var accumulatedContentLength: Int = 0
    var accumulatedThinkingChunks: [String] = []
    var accumulatedThinkingLength: Int = 0
    var accumulatedToolCalls: [ToolCall] = []
    var streamError: String?
    var currentToolCallId: String?
    var currentToolCallName: String?
    var currentToolCallArgumentChunks: [String] = []
    var inputTokens: Int?
    var outputTokens: Int?
    var stopReason: String?
    var timeToFirstToken: Double?
    var isFirstToken = true
    let startTime: CFAbsoluteTime

    init(startTime: CFAbsoluteTime) {
        self.startTime = startTime
    }

    @discardableResult
    func recordFirstToken() -> Double? {
        guard isFirstToken else { return nil }
        isFirstToken = false
        let firstTokenTime = CFAbsoluteTimeGetCurrent()
        let ttft = (firstTokenTime - startTime) * 1000.0
        timeToFirstToken = ttft
        return ttft
    }

    func appendContent(_ content: String) {
        accumulatedContentChunks.append(content)
        accumulatedContentLength += content.count
    }

    func appendThinking(_ content: String) {
        guard !content.isEmpty else { return }
        guard accumulatedThinkingLength < AgentConfig.maxThinkingTextLength else { return }
        let remaining = AgentConfig.maxThinkingTextLength - accumulatedThinkingLength
        let part = String(content.prefix(remaining))
        guard !part.isEmpty else { return }
        accumulatedThinkingChunks.append(part)
        accumulatedThinkingLength += part.count
    }

    func startNewToolCall(_ toolCall: ToolCall, hasPartialJson: Bool = false) {
        currentToolCallId = toolCall.id
        currentToolCallName = toolCall.name
        if !hasPartialJson && !toolCall.arguments.isEmpty && toolCall.arguments != "{}" {
            currentToolCallArgumentChunks = [toolCall.arguments]
        } else {
            currentToolCallArgumentChunks = []
        }
    }

    func finalizeCurrentToolCall() -> ToolCall? {
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
        return ToolCall(id: currentId, name: currentName, arguments: arguments)
    }

    func saveCurrentToolCall() {
        if let toolCall = finalizeCurrentToolCall() {
            accumulatedToolCalls.append(toolCall)
            currentToolCallId = nil
            currentToolCallName = nil
            currentToolCallArgumentChunks = []
        }
    }

    func appendToolCallArguments(_ partialJson: String) {
        currentToolCallArgumentChunks.append(partialJson)
    }

    func setError(_ error: String) {
        streamError = error
    }

    func updateTokens(input: Int?, output: Int?) {
        if let input = input { inputTokens = input }
        if let output = output { outputTokens = output }
    }

    func setStopReason(_ reason: String) {
        stopReason = reason
    }
}
