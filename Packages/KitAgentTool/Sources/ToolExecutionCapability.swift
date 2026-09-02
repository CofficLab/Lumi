import Foundation

/// Describes the scheduling safety requirements of a tool invocation.
public enum ToolExecutionCapability: Sendable, Equatable {
    /// The tool may change external state and must be serialized within a turn.
    case serialSideEffect

    /// The tool only observes state and may run concurrently with other reads.
    case parallelReadOnly

    /// The tool interacts with the user and blocks later work in the same turn.
    case interactive
}
