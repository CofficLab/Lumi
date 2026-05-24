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
/// - `execute(arguments:context:)`: 实际执行工具逻辑
public protocol SuperAgentTool: Sendable {
    /// 工具名称（唯一标识符，不翻译）
    var name: String { get }

    /// 工具描述（多语言）
    func description(for language: LanguagePreference) -> String

    /// 输入参数 JSON Schema（多语言）
    func inputSchema(for language: LanguagePreference) -> [String: Any]

    /// 带上下文的执行入口
    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String

    /// 工具自行评估当前调用的风险等级（必填）
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel

    /// 根据当前调用参数返回面向用户的简短操作描述
    ///
    /// 例如：
    /// - `EditFileTool` → `"编辑 Foo.swift"`
    /// - `ShellTool` → `"执行 git status"`
    /// - `ReadFileTool` → `"读取 Bar.swift"`
    ///
    /// 返回 `nil` 时，UI 层将回退到显示 `toolCall.name`。
    /// - Parameter arguments: 本次调用的参数
    /// - Returns: 人类可读的操作描述，或 `nil`
    func displayDescription(for arguments: [String: ToolArgument]) -> String?
}

extension SuperAgentTool {
    /// 默认描述（英文）
    public var description: String {
        description(for: .english)
    }

    /// 默认 inputSchema（英文）
    public var inputSchema: [String: Any] {
        inputSchema(for: .english)
    }

    /// 默认不提供操作描述，UI 层将回退到显示 `toolCall.name`
    public func displayDescription(for arguments: [String: ToolArgument]) -> String? {
        nil
    }
}
