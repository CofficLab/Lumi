import Foundation

/// 代理工具协议
///
/// 定义 LLM 可以调用的工具/函数接口。
/// 工具允许 AI 助手执行特定操作，如读写文件、执行命令等。
///
/// 每个工具需要实现：
/// - `name`: 唯一名称，用于 AI 选择工具
/// - `description(for:)`: 功能描述，帮助 AI 理解何时使用
/// - `inputSchema(for:)`: 输入参数的 JSON Schema
/// - `permissionRiskLevel(arguments:)`: 当前调用的风险等级（必填）
public protocol SuperAgentTool: Sendable {
    /// 工具名称（唯一标识符，不翻译）
    var name: String { get }

    /// 工具描述（多语言）
    func description(for language: LanguagePreference) -> String

    /// 输入参数 JSON Schema（多语言）
    func inputSchema(for language: LanguagePreference) -> [String: Any]

    /// 工具自行评估当前调用的风险等级（必填）
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel

    /// Declares whether this tool can safely run concurrently with other jobs.
    ///
    /// Existing and third-party tools get the conservative serial default from
    /// the protocol extension below until they explicitly opt into parallel
    /// read-only execution.
    var executionCapability: ToolExecutionCapability { get }

    /// 根据当前调用参数返回面向用户的简短操作描述（必填）
    ///
    /// 每个工具必须提供面向用户的操作描述，帮助用户快速理解当前操作。
    /// 描述应简洁明了，通常为"动词 + 关键参数"格式。
    ///
    /// 例如：
    /// - `EditFileTool` → `"编辑 Foo.swift"`
    /// - `ShellTool` → `"执行 git status"`
    /// - `ReadFileTool` → `"读取 Bar.swift"`
    /// - `GitStatusTool` → `"查看 Git 状态"`
    ///
    /// - Parameter arguments: 本次调用的参数
    /// - Returns: 人类可读的操作描述
    func displayDescription(for arguments: [String: ToolArgument]) -> String

    /// 执行工具（必填）
    ///
    /// 由宿主（如 `ToolManagerProviding`）在授权/风险评估通过后调用。
    /// 返回值会作为工具结果文本回传给 LLM；执行失败时抛出错误。
    ///
    /// - Parameter arguments: 本次调用的参数（由宿主从 `ToolCall.arguments` 解码）
    /// - Returns: 工具执行结果文本
    func execute(arguments: [String: ToolArgument]) async throws -> String

    /// 执行工具并返回结构化结果（协议要求）。
    ///
    /// 宿主（`ToolManagerProviding`）对 `any SuperAgentTool` 调用本方法。
    /// **必须声明为协议要求**：若仅放在扩展中，对存在类型调用时会静态分派到
    /// 默认实现，工具自身覆盖的版本永远不会被调用（Swift 存在类型 + 扩展方法
    /// 的静态分派限制）。
    ///
    /// 默认实现把 `execute(arguments:)` 的文本包装为 `ToolCallResult`。
    /// 需要结构化结果的工具（图片附件、`awaitingUserResponse` 挂起等）
    /// 应覆盖本方法。例如 AskUser 工具返回 `awaitingUserResponse: true`
    /// 让 Agent 循环暂停等待用户回答。
    func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult

    /// 带执行上下文的结构化工具执行接口。
    ///
    /// 新工具可以通过 Context 查询取消状态，并持续上报输出和进度。
    /// 旧工具无需修改，默认实现会转发到无 Context 的旧接口。
    func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult
}

extension SuperAgentTool {
    /// Unknown/custom tools are serialized by default because their side
    /// effects cannot be inferred safely from the protocol alone.
    public var executionCapability: ToolExecutionCapability { .serialSideEffect }

    /// 默认描述（英文）
    public var description: String {
        description(for: .english)
    }

    /// 默认 inputSchema（英文）
    public var inputSchema: [String: Any] {
        inputSchema(for: .english)
    }

    /// 默认执行实现：抛错提示未实现。
    ///
    /// 提供默认实现以保持旧实现（未迁移 execute 的工具）可编译；
    /// 新工具必须实现 `execute(arguments:)`，否则执行时返回该错误。
    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        throw ToolExecutionError.executionFailed(
            toolName: name,
            reason: "\(name) does not implement execute(arguments:)"
        )
    }

    /// 执行工具并返回结构化结果（默认实现）。
    ///
    /// 默认将 `execute(arguments:)` 的文本内容包装为 `ToolCallResult`。
    /// 需要返回图片附件等结构化结果的工具（如预览渲染图）可覆盖此方法。
    public func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        ToolCallResult(content: try await execute(arguments: arguments))
    }

    /// 兼容旧工具的默认实现：忽略 Context，继续调用旧接口。
    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        _ = context
        return try await executeResult(arguments: arguments)
    }
}
