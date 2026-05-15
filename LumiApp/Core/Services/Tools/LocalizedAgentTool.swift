import Foundation

/// 语言感知的工具包装器
///
/// 将任意 `SuperAgentTool` 包装为返回特定语言描述和 schema 的版本。
/// Provider 层无需关心语言——它拿到的工具已经是选定语言的。
///
/// ## 工作原理
///
/// - **name**: 不翻译，直接透传
/// - **description**: 调用底层工具的 `description(for:)` 方法，传入固定语言
/// - **inputSchema**: 调用底层工具的 `inputSchema(for:)` 方法，传入固定语言
/// - **execute**: 完全透传给底层工具
/// - **permissionRiskLevel**: 完全透传给底层工具
struct LocalizedAgentTool: SuperAgentTool, Sendable {
    let underlying: SuperAgentTool
    let language: LanguagePreference

    var name: String { underlying.name }

    func description(for language: LanguagePreference) -> String {
        // 忽略传入的 language，使用包装时确定的语言
        underlying.description(for: self.language)
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        underlying.inputSchema(for: self.language)
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await underlying.execute(arguments: arguments)
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try await underlying.execute(arguments: arguments, context: context)
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        underlying.permissionRiskLevel(arguments: arguments)
    }
}
