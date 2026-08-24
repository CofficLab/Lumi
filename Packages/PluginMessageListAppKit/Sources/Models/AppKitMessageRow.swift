import Foundation
import KernelLumi

/// One immutable, display-ready row of the native message list.
///
/// Rows are pure value types: they never carry `NSView`, closures, colors, or
/// service objects, so snapshots can be built off the main actor and diffed
/// cheaply. `id` is stable across snapshot refreshes — the same underlying
/// message (or synthesized group) keeps its identity when a streaming row
/// becomes persisted history.
public struct AppKitMessageRow: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case user
        case assistant
        case system
        case status
        case error
        case tool
        /// Synthesized assistant row grouping consecutive tool-execution-only
        /// messages (renderKind `turn-activity` / `tool-step-group`).
        case toolStepGroup
        /// V1 (brief) turn conclusion row projected from an AgentTurn.
        case conclusion
        /// Live streaming tail row (V2 only). Never persisted.
        case streaming
        /// Generic fallback for unrecognized content.
        case fallback
    }

    /// Stable identity. Defaults to the underlying message UUID, but V1
    /// conclusion rows use `turn-<turnID>` so a re-projected turn keeps its row.
    public let id: String
    public let kind: Kind
    public let message: LumiChatMessage
    /// The AgentTurn this row belongs to, when known (used by headers and
    /// turn-aware renderers). May be nil for legacy messages.
    public let sourceTurnID: UUID?

    public init(
        id: String? = nil,
        kind: Kind,
        message: LumiChatMessage,
        sourceTurnID: UUID? = nil
    ) {
        self.id = id ?? message.id.uuidString
        self.kind = kind
        self.message = message
        self.sourceTurnID = sourceTurnID
    }

    /// Infers the display kind from the message role / content.
    public static func from(message: LumiChatMessage) -> AppKitMessageRow {
        let kind: Kind
        switch message.role {
        case .user: kind = .user
        case .assistant:
            kind = message.renderKind == "tool-step-group" || message.renderKind == "turn-activity"
                ? .toolStepGroup
                : .assistant
        case .tool: kind = .tool
        case .system: kind = .system
        case .error: kind = .error
        case .status: kind = .status
        }
        return AppKitMessageRow(kind: kind, message: message, sourceTurnID: message.turnID)
    }
}

extension AppKitMessageRow {
    /// Convenience accessors forwarded to the underlying message.
    public var role: LumiChatMessageRole { message.role }
    public var content: String { message.content }
    public var createdAt: Date { message.createdAt }
    public var isError: Bool { message.isError }
    public var renderKind: String? { message.renderKind }
    public var toolCalls: [LumiToolCall]? { message.toolCalls }
    public var isToolExecutionOnly: Bool { message.isToolExecutionOnly }
}
