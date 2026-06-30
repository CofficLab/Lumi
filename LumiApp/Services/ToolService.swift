import Foundation
import LumiCoreKit

@MainActor
final class ToolService: LumiToolServicing {
    private(set) var tools: [any LumiAgentTool] = []
    private var toolsByName: [String: any LumiAgentTool] = [:]
    var projectPathProvider: (any LumiCurrentProjectPathProviding)?

    func registerTools(_ tools: [any LumiAgentTool]) {
        var uniqueTools: [String: any LumiAgentTool] = [:]

        for tool in tools {
            if let existing = uniqueTools[tool.name] {
                let existingType = String(describing: type(of: existing))
                let newType = String(describing: type(of: tool))
                fatalError("Duplicate tool name '\(tool.name)': existing=\(existingType), new=\(newType)")
            }
            uniqueTools[tool.name] = tool
        }

        self.toolsByName = uniqueTools
        self.tools = uniqueTools.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// 注册 built-in tools（如 conversation_info, no_op）
    /// 这些工具会合并到现有的工具字典中
    func registerBuiltInTools(_ tools: [any LumiAgentTool]) {
        for tool in tools {
            // 不覆盖已存在的工具（插件提供的工具优先）
            if toolsByName[tool.name] == nil {
                toolsByName[tool.name] = tool
            }
        }
        // 重新排序
        self.tools = toolsByName.values.sorted {
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
            // 工具可能在执行过程中通过 context.attachImage 注册了要回传的图片
            // （如 read_file 读取图片文件），这里收集并填入结果。
            let images = context.collectImages()
            return LumiToolResult(
                content: output,
                duration: Date().timeIntervalSince(startedAt),
                imageAttachments: images
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
