import Foundation
import LumiComponentMessage
import os
/// 工具服务
///
/// 管理所有注册的工具，提供注册、查找和执行工具的能力。
/// 通过 ToolServiceEnvironment 协议获取运行时上下文（如 verbosity、projectPath），
/// 避免直接依赖 LumiCore 全局状态。
@MainActor
public final class ToolService: LumiToolServicing {
    nonisolated public static let logger = Logger(subsystem: "com.coffic.lumi", category: "service.tool")
    nonisolated public static let emoji = "🛠️"
    nonisolated public static let verbose = false

    /// 运行时环境（由 LumiCore 在启动时注入）
    public var environment: (any ToolServiceEnvironment)?

    private(set) public var tools: [any LumiAgentTool] = []
    private var toolsByName: [String: any LumiAgentTool] = [:]

    public init() {}

    /// per-request 构造：直接用一份已去重的工具集初始化。
    ///
    /// 供动态注入路径（`AgentToolComponent.buildToolSet`）使用——每次发消息时
    /// 构建一份全新的 `ToolService`，本次 turn 序列内全程持有，请求结束即释放。
    /// 多个会话因此天然隔离，不会互相覆盖工具集。
    ///
    /// - Parameters:
    ///   - tools: 本次请求要暴露给 LLM 的工具集。本构造器不做去重——调用方
    ///     （`buildToolSet`）应已做完软去重，这里直接覆盖式装载，后到同名工具
    ///     压盖先到者。
    ///   - environment: 运行时环境（verbosity / currentProjectPath），由启动期
    ///     注入的 bridge 提供，可被多个 per-request 实例共享（只读消费）。
    public init(tools: [any LumiAgentTool], environment: (any ToolServiceEnvironment)?) {
        self.environment = environment
        self.toolsByName = Dictionary(tools.map { ($0.name, $0) }, uniquingKeysWith: { last, _ in last })
        reindex()
        if Self.verbose {
            Self.logger.info("\(Self.emoji)per-request 工具集构建完成，总计 \(self.tools.count) 个")
        }
    }

    // MARK: - Registration

    /// 注册工具（覆盖已有同名工具）
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

    /// 追加工具（不覆盖已有同名工具）
    ///
    /// 与 `registerTools(_:)` 不同，`appendTools(_:)` 在已有的 `toolsByName`
    /// 字典上合并——已存在的工具名不会被替换。适用于分层注册场景，例如：
    ///
    /// 1. `registerTools(pluginService.agentTools(...))` 清空并装载插件工具
    /// 2. `registerBuiltInTools(...)` 追加内置工具
    /// 3. `appendTools(subAgentDelegateTools)` 追加子 Agent delegate 工具
    ///
    /// 重复调用是安全的，但应避免在一次 reload 中重复追加同一工具。
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

    /// 注册内置工具（如 conversation_info, no_op）
    ///
    /// 复用 `appendTools(_:)` 的合并语义：已存在同名工具时跳过，不覆盖。
    public func registerBuiltInTools(_ tools: [any LumiAgentTool]) {
        if Self.verbose {
            Self.logger.info("\(Self.emoji)注册 \(tools.count) 个内置工具")
        }
        appendTools(tools)
    }

    // MARK: - Lookup

    /// 根据名称查找工具
    public func tool(named name: String) -> (any LumiAgentTool)? {
        toolsByName[name]
    }

    // MARK: - Execution

    /// 执行工具调用
    public func execute(_ toolCall: LumiToolCall, conversationID: UUID) async -> LumiToolResult {
        guard let tool = tool(named: toolCall.name) else {
            if Self.verbose {
                Self.logger.warning("\(Self.emoji)工具未找到: \(toolCall.name)")
            }
            return LumiToolResult(
                content: "Tool not found: \(toolCall.name)",
                isError: true
            )
        }

        if Self.verbose {
            Self.logger.info("\(Self.emoji)执行工具: \(toolCall.name)")
        }

        // 从环境获取 verbosity 和 projectPath
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

            // 工具可能在执行过程中通过 context.attachImage 注册了要回传给 LLM 的图片
            // （如 read_file 读取图片文件），这里收集并填入结果。
            let images = context.collectImages()
            let duration = Date().timeIntervalSince(startedAt)

            if Self.verbose {
                Self.logger.info("\(Self.emoji)工具执行完成: \(toolCall.name) (\(String(format: "%.2f", duration * 1000))ms)")
            }

            return LumiToolResult(
                content: output,
                duration: duration,
                imageAttachments: images
            )
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

    /// 用 `toolsByName` 重建按名字排序的 `tools` 数组。
    ///
    /// 任何改动 `toolsByName` 的写路径（`init(tools:)` / `registerTools` /
    /// `appendTools`）都应调用本方法收尾，保证 `tools` 与 `toolsByName` 永远同步。
    private func reindex() {
        tools = toolsByName.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private static func decodeArguments(_ json: String) throws -> [String: LumiJSONValue] {
        guard let data = json.data(using: .utf8), !data.isEmpty else {
            return [:]
        }

        return try JSONDecoder().decode([String: LumiJSONValue].self, from: data)
    }
}
