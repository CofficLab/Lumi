import Foundation
import os

/// 工具服务
@MainActor
public final class ToolService: ToolManaging {
    nonisolated public static let logger = Logger(subsystem: "com.coffic.lumi", category: "service.tool")
    nonisolated public static let emoji = "🛠️"
    nonisolated public static let verbose = false

    public var environment: (any ToolServiceEnvironment)?

    private(set) public var tools: [any LumiAgentTool] = []
    private var toolsByName: [String: any LumiAgentTool] = [:]

    public init() {}

    public init(tools: [any LumiAgentTool], environment: (any ToolServiceEnvironment)?) {
        self.environment = environment
        self.toolsByName = Dictionary(tools.map { ($0.name, $0) }, uniquingKeysWith: { last, _ in last })
        reindex()
        if Self.verbose {
            Self.logger.info("\(Self.emoji)per-request 工具集构建完成，总计 \(self.tools.count) 个")
        }
    }

    // MARK: - ToolManaging Registration

    public func allAgentTools() -> [any LumiAgentTool] {
        tools
    }

    public func add(_ tool: any LumiAgentTool) {
        if toolsByName[tool.name] == nil {
            toolsByName[tool.name] = tool
            reindex()
        }
    }

    public func remove(id: String) {
        toolsByName.removeValue(forKey: id)
        reindex()
    }

    public func allSubAgents() -> [LumiSubAgentDefinition] {
        []
    }

    public func addSubAgent(_ subAgent: LumiSubAgentDefinition) {
        // Sub-agents not supported in per-request ToolService
    }

    public func registerTools(_ tools: [any LumiAgentTool]) throws {
        if Self.verbose {
            Self.logger.info("\(Self.emoji)注册 \(tools.count) 个工具")
        }
        try LumiToolNameDeduplication.validateUnique(tools: tools)
        var uniqueTools: [String: any LumiAgentTool] = [:]
        for tool in tools {
            uniqueTools[tool.name] = tool
        }
        self.toolsByName = uniqueTools
        reindex()
        if Self.verbose {
            Self.logger.info("\(Self.emoji)✅ 工具注册完成，总计 \(self.tools.count) 个")
        }
    }

    public func appendTools(_ tools: [any LumiAgentTool]) {
        if Self.verbose {
            Self.logger.info("\(Self.emoji)追加 \(tools.count) 个工具")
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
        reindex()
        if Self.verbose {
            Self.logger.info("\(Self.emoji)✅ 工具追加完成，新增 \(appendedCount) 个，跳过 \(skippedCount) 个；当前总计 \(self.tools.count) 个")
        }
    }

    public func registerBuiltInTools(_ tools: [any LumiAgentTool]) {
        if Self.verbose {
            Self.logger.info("\(Self.emoji)注册 \(tools.count) 个内置工具")
        }
        appendTools(tools)
    }

    // MARK: - Lookup

    public func tool(named name: String) -> (any LumiAgentTool)? {
        toolsByName[name]
    }

    // MARK: - Execution

    public func execute(_ toolCall: LumiToolCall, conversationID: UUID) async -> LumiToolResult {
        guard let tool = tool(named: toolCall.name) else {
            if Self.verbose {
                Self.logger.warning("\(Self.emoji)工具未找到: \(toolCall.name)")
            }
            return LumiToolResult(content: "Tool not found: \(toolCall.name)", isError: true)
        }

        if Self.verbose {
            Self.logger.info("\(Self.emoji)执行工具: \(toolCall.name)")
        }

        let verbosity = environment?.verbosity(for: conversationID).rawValue
        let projectPath = environment?.currentProjectPath
        let startedAt = Date()
        let context = LumiToolExecutionContext(
            conversationID: conversationID,
            toolCallID: toolCall.id,
            toolName: toolCall.name,
            currentProjectPath: projectPath,
            verbosity: verbosity
        )

        do {
            let arguments = try Self.decodeArguments(toolCall.arguments)
            let output = try await Task.detached { [context] in
                try await tool.execute(arguments: arguments, context: context)
            }.value
            let images = context.collectImages()
            let duration = Date().timeIntervalSince(startedAt)
            if Self.verbose {
                Self.logger.info("\(Self.emoji)工具执行完成: \(toolCall.name) (\(String(format: "%.2f", duration * 1000))ms)")
            }
            return LumiToolResult(content: output, duration: duration, imageAttachments: images)
        } catch {
            if Self.verbose {
                Self.logger.error("\(Self.emoji)工具执行失败: \(toolCall.name) - \(error.localizedDescription)")
            }
            return LumiToolResult(
                content: "Tool execution failed: \(error.localizedDescription)",
                duration: Date().timeIntervalSince(startedAt),
                isError: true
            )
        }
    }

    // MARK: - Private

    private func reindex() {
        tools = toolsByName.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private static func decodeArguments(_ json: String) throws -> [String: LumiJSONValue] {
        guard let data = json.data(using: .utf8), !data.isEmpty else { return [:] }
        return try JSONDecoder().decode([String: LumiJSONValue].self, from: data)
    }
}
