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
    var totalTokens: Int?
    var stopReason: String?
    var timeToFirstToken: Double?
    var firstTokenTime: CFAbsoluteTime?
    var isFirstToken = true
    let startTime: CFAbsoluteTime

    init(startTime: CFAbsoluteTime) {
        self.startTime = startTime
    }

    @discardableResult
    func recordFirstToken() -> Double? {
        guard isFirstToken else { return nil }
        isFirstToken = false
        let now = CFAbsoluteTimeGetCurrent()
        firstTokenTime = now
        let ttft = (now - startTime) * 1000.0
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
        // 自动计算 totalTokens
        if let input = inputTokens, let output = outputTokens {
            totalTokens = input + output
        } else {
            totalTokens = nil
        }
    }

    func setStopReason(_ reason: String) {
        stopReason = reason
    }
    
    /// 计算流式传输耗时（从第一个 token 到完成的时间）
    /// - Returns: 流式传输耗时（毫秒），如果没有第一个 token 则返回 nil
    func getStreamingDuration() -> Double? {
        guard let firstTokenTime = firstTokenTime else { return nil }
        let now = CFAbsoluteTimeGetCurrent()
        return (now - firstTokenTime) * 1000.0
    }

    /// 获取最终的思考内容
    /// - Returns: 思考内容字符串，如果为空则返回 nil
    func getFinalThinking() -> String? {
        let thinking = accumulatedThinkingChunks.joined()
        return thinking.isEmpty ? nil : thinking
    }

    /// 获取最终的工具调用列表
    /// - Returns: 工具调用数组，如果为空则返回 nil
    func getFinalToolCalls() -> [ToolCall]? {
        return accumulatedToolCalls.isEmpty ? nil : accumulatedToolCalls
    }
}