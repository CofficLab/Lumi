import Foundation

/// 语言感知的工具包装器
///
/// 将任意 `SuperAgentTool` 包装为返回特定语言描述和 schema 的版本。
/// Provider 层无需关心语言——它拿到的工具已经是选定语言的。
public struct LocalizedAgentTool: SuperAgentTool, Sendable {
    public let underlying: SuperAgentTool
    public let language: LanguagePreference

    public var name: String { underlying.name }

    public init(underlying: SuperAgentTool, language: LanguagePreference) {
        self.underlying = underlying
        self.language = language
    }

    public func description(for language: LanguagePreference) -> String {
        underlying.description(for: self.language)
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        underlying.inputSchema(for: self.language)
    }

    public func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try await underlying.execute(arguments: arguments, context: context)
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        underlying.permissionRiskLevel(arguments: arguments)
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        underlying.displayDescription(for: arguments)
    }
}
