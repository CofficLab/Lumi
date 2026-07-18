// MARK: - Checks
//
// Pluggable checks that run after each LLM response in the agent loop.
// Each check implements `LumiAgentTurnCheck` (defined in this package).
//
// To add a new check:
// 1. Create a new Swift file in this directory
// 2. Implement `LumiAgentTurnCheck`
// 3. Add it to the default `turnChecks` list in `ChatService.swift`

// MARK: - ToolLoopLimitCheck

import Foundation

/// Terminates the agent loop when the iteration count exceeds a configured maximum.
///
/// This prevents runaway tool-call cycles where the LLM repeatedly produces tool calls
/// without converging on a final answer.
public struct ToolLoopLimitCheck: LumiAgentTurnCheck, Sendable {
    /// Maximum number of iterations allowed before the loop is terminated.
    public let maxIterations: Int

    public init(maxIterations: Int = 120) {
        self.maxIterations = maxIterations
    }

    public func evaluate(_ context: TurnContext) async -> String? {
        guard context.iteration >= maxIterations else {
            return nil
        }
        return "Tool call limit reached (\(maxIterations)). The assistant stopped to avoid an infinite tool loop."
    }
}
