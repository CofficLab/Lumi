import Foundation

/// Worker 对 LLM 能力的最小依赖
protocol WorkerLLMServiceProtocol: Sendable {
    func sendMessage(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [AgentTool]?
    ) async throws -> ChatMessage
}

/// Worker 对工具能力的最小依赖
protocol WorkerToolServiceProtocol: Sendable {
    var tools: [AgentTool] { get }
    func requiresPermission(toolName: String, argumentsJSON: String?) -> Bool
    func executeTool(named name: String, argumentsJSON: String) async throws -> String
}

extension LLMService: WorkerLLMServiceProtocol {}
extension ToolService: WorkerToolServiceProtocol {}
