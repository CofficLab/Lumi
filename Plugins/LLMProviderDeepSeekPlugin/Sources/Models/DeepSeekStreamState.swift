import Foundation
import LumiKernel

actor DeepSeekStreamState {
    var content = ""
    var reasoning = ""
    var toolCalls: [LumiToolCall] = []
    var activeToolID: String?
    var activeToolName: String?
    var activeToolArguments = ""
    var inputTokens: Int?
    var outputTokens: Int?
    var cacheHitTokens: Int?
    var cacheTotalInputTokens: Int?
    var stopReason: String?
    var error: String?

    func setError(_ value: String) { error = value }

    func append(_ event: DeepSeekEvent) {
        if let value = event.content { content += value }
        if let value = event.reasoning { reasoning += value }
        if let value = event.inputTokens { inputTokens = value }
        if let value = event.outputTokens { outputTokens = value }
        if let value = event.cacheHitTokens { cacheHitTokens = value }
        if let value = event.cacheTotalInputTokens { cacheTotalInputTokens = value }
        if let value = event.stopReason { stopReason = value }

        for delta in event.toolDeltas {
            let id = delta.id
            let name = delta.name
            let arguments = delta.arguments
            if id != nil || name != nil {
                saveTool()
                activeToolID = id ?? UUID().uuidString
                activeToolName = name ?? ""
                activeToolArguments = arguments
            } else {
                activeToolArguments += arguments
            }
        }
    }

    func saveTool() {
        guard let id = activeToolID, let name = activeToolName else { return }
        toolCalls.append(LumiToolCall(id: id, name: name, arguments: activeToolArguments.isEmpty ? "{}" : activeToolArguments))
        activeToolID = nil
        activeToolName = nil
        activeToolArguments = ""
    }
}
