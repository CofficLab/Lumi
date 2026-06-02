import Foundation

/// Plugin-provided definition for a kernel-managed sub-agent.
///
/// A definition is declarative: plugins describe the type, prompt, allowed tools,
/// and expected result fields. The app core owns scheduling, model selection, and
/// tool execution.
public protocol SubAgentDefinitionProtocol: Sendable {
    /// Stable type identifier, for example `git.commit`.
    var id: String { get }

    /// Human-readable name for UI and tool results.
    var name: String { get }

    /// Short task description surfaced in tool schemas and status text.
    var description: String { get }

    /// System prompt used for the isolated sub-agent loop.
    var systemPrompt: String { get }

    /// Tool names the sub-agent may see and execute.
    var allowedToolNames: [String] { get }

    /// Maximum LLM turns before the sub-agent fails.
    var maxTurns: Int { get }

    /// Expected JSON result fields and display formatting.
    var resultTemplate: SubAgentResultTemplate { get }
}

public struct SubAgentResultTemplate: Sendable {
    public let fields: [SubAgentResultField]
    public let successFormat: String
    public let failureFormat: String

    public init(
        fields: [SubAgentResultField],
        successFormat: String,
        failureFormat: String
    ) {
        self.fields = fields
        self.successFormat = successFormat
        self.failureFormat = failureFormat
    }
}

public enum SubAgentResultField: String, Sendable, CaseIterable {
    case commitHash = "commit_hash"
    case commitMessage = "commit_message"
    case status
    case duration
    case output
    case error
}
