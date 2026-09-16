import Foundation
import KitAgentTool

/// Supplies the owning conversation's project as the default Git path.
/// The selected project in the UI may belong to a different conversation while
/// an earlier turn is still executing.
struct ConversationScopedGitTool: SuperAgentTool, @unchecked Sendable {
    private let base: any SuperAgentTool

    init(_ base: any SuperAgentTool) {
        self.base = base
    }

    var name: String { base.name }
    var executionCapability: ToolExecutionCapability { base.executionCapability }

    func description(for language: LanguagePreference) -> String {
        base.description(for: language)
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        base.inputSchema(for: language)
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        base.permissionRiskLevel(arguments: arguments)
    }

    func displayDescription(for arguments: [String: ToolArgument]) -> String {
        base.displayDescription(for: arguments)
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await base.execute(arguments: arguments)
    }

    func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        var scopedArguments = arguments
        let requestedPath = GitV2ToolSupport.string(arguments, "path")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if requestedPath?.isEmpty != false,
           let conversationPath = await context.conversationProjectPath() {
            scopedArguments["path"] = ToolArgument(conversationPath)
        }
        return try await base.executeResult(arguments: scopedArguments)
    }
}
