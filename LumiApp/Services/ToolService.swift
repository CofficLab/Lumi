import Foundation
import LumiChatKit
import LumiCoreKit
import SuperLogKit
import os

final class ToolService: LumiToolServicing, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "service.tool")
    nonisolated static let emoji = "🛠️"
    nonisolated static let verbose = false  // 临时开启用于调试子Agent注册

    private(set) var tools: [any LumiAgentTool] = []
    private var toolsByName: [String: any LumiAgentTool] = [:]

    func registerTools(_ tools: [any LumiAgentTool]) {
        if Self.verbose {
            Self.logger.info("\(Self.t)注册 \(tools.count) 个工具")
        }

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

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ 工具注册完成，总计 \(self.tools.count) 个")
        }
    }

    /// 仅追加工具（不覆盖同名）。
    ///
    /// 与 `registerTools(_:)` 不同，`appendTools(_:)` 在已有的 `toolsByName`
    /// 字典上合并——已存在的工具名不会被替换。适用于分层注册场景，例如：
    ///
    /// 1. `registerTools(pluginService.agentTools(...))` 清空并装载插件工具
    /// 2. `registerBuiltInTools(...)` 追加内置工具
    /// 3. `appendTools(subAgentDelegateTools)` 追加子 Agent delegate 工具
    ///
    /// 重复调用是安全的，但应避免在一次 reload 中重复追加同一工具。
    func appendTools(_ tools: [any LumiAgentTool]) {
        if Self.verbose {
            Self.logger.info("\(Self.t)追加 \(tools.count) 个工具")
        }

        var appendedCount = 0
        var skippedCount = 0
        for tool in tools {
            if toolsByName[tool.name] == nil {
                toolsByName[tool.name] = tool
                appendedCount += 1
            } else {
                skippedCount += 1
            }
        }
        self.tools = toolsByName.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ 工具追加完成，新增 \(appendedCount) 个，跳过 \(skippedCount) 个；当前总计 \(self.tools.count) 个")
        }
    }

    /// 注册 built-in tools（如 conversation_info, no_op）。
    /// 复用 `appendTools(_:)` 的合并语义：已存在同名工具时跳过，不覆盖。
    func registerBuiltInTools(_ tools: [any LumiAgentTool]) {
        if Self.verbose {
            Self.logger.info("\(Self.t)注册 \(tools.count) 个内置工具")
        }
        appendTools(tools)
    }

    func tool(named name: String) -> (any LumiAgentTool)? {
        toolsByName[name]
    }

    func execute(_ toolCall: LumiToolCall, conversationID: UUID) async -> LumiToolResult {
        guard let tool = tool(named: toolCall.name) else {
            if Self.verbose {
                Self.logger.warning("\(Self.t)工具未找到: \(toolCall.name)")
            }
            return LumiToolResult(
                content: "Tool not found: \(toolCall.name)",
                isError: true
            )
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)执行工具: \(toolCall.name)")
        }

        // 获取当前会话的详细程度
        let verbosity = (LumiCore.chatService as? ChatService)?
            .verbosity(for: conversationID)
            .rawValue

        let startedAt = Date()
        let context = LumiToolExecutionContext(
            conversationID: conversationID,
            toolCallID: toolCall.id,
            toolName: toolCall.name,
            currentProjectPath: LumiCore.projectState?.currentProject?.path,
            verbosity: verbosity
        )

        do {
            let arguments = try Self.decodeArguments(toolCall.arguments)
            let output = try await Task.detached { [context] in
                try await tool.execute(arguments: arguments, context: context)
            }.value

            // 工具可能在执行过程中通过 context.attachImage 注册了要回传给 LLM 的图片
            // （如 read_file 读取图片文件），这里收集并填入结果。
            let images = context.collectImages()
            let duration = Date().timeIntervalSince(startedAt)

            if Self.verbose {
                Self.logger.info("\(Self.t)工具执行完成: \(toolCall.name) (\(String(format: "%.2f", duration * 1000))ms)")
            }

            return LumiToolResult(
                content: output,
                duration: duration,
                imageAttachments: images
            )
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.t)工具执行失败: \(toolCall.name) - \(error.localizedDescription)")
            }
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