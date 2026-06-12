import Foundation
import LumiCoreKit

@MainActor
final class ToolService: LumiToolServicing {
    private(set) var tools: [any LumiAgentTool] = []
    private var toolsByName: [String: any LumiAgentTool] = [:]
    var projectPathProvider: (any LumiCurrentProjectPathProviding)?

    func registerTools(_ tools: [any LumiAgentTool]) {
        let uniqueTools = tools.reduce(into: [String: any LumiAgentTool]()) { result, tool in
            result[tool.name] = tool
        }

        self.toolsByName = uniqueTools
        self.tools = uniqueTools.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    func tool(named name: String) -> (any LumiAgentTool)? {
        toolsByName[name]
    }

    func execute(_ toolCall: LumiToolCall, conversationID: UUID) async -> LumiToolResult {
        guard let tool = tool(named: toolCall.name) else {
            return LumiToolResult(
                content: "Tool not found: \(toolCall.name)",
                isError: true
            )
        }

        let startedAt = Date()
        let context = LumiToolExecutionContext(
            conversationID: conversationID,
            toolCallID: toolCall.id,
            toolName: toolCall.name,
            currentProjectPath: projectPathProvider?.currentProjectPath
        )

        do {
            let arguments = try Self.decodeArguments(toolCall.arguments)
            let output = try await tool.execute(arguments: arguments, context: context)
            return LumiToolResult(
                content: output,
                duration: Date().timeIntervalSince(startedAt)
            )
        } catch {
            return LumiToolResult(
                content: "Tool execution failed: \(error.localizedDescription)",
                duration: Date().timeIntervalSince(startedAt),
                isError: true
            )
        }
    }

    private static func decodeArguments(_ json: String) throws -> [String: LumiJSONValue] {
        guard let data = json.data(using: .utf8), !data.isEmpty else {
            return [:]
        }

        return try JSONDecoder().decode([String: LumiJSONValue].self, from: data)
    }
}
