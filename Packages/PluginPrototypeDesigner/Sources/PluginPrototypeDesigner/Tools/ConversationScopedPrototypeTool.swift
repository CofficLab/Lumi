import Foundation
import KitAgentTool

/// Tool calls use the project bound to their conversation, even if the user
/// switches the selected conversation while a turn is still running.
enum PrototypeConversationProjectScope {
    enum Binding: Sendable {
        case unscoped
        case conversation(projectPath: String?)
    }

    @TaskLocal static var binding: Binding = .unscoped
}

/// Adds the owning conversation's project as an execution-local default for a
/// prototype tool without changing the public schemas of the individual tools.
struct ConversationScopedPrototypeTool: SuperAgentTool {
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

    func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        try await base.executeResult(arguments: arguments)
    }

    func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        let projectPath = await context.conversationProjectPath()
        return try await PrototypeConversationProjectScope.$binding.withValue(
            .conversation(projectPath: projectPath)
        ) {
            try await base.executeResult(arguments: arguments)
        }
    }
}
