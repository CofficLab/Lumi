import Foundation

// MARK: - Agent Tools Default Implementation

extension SuperPlugin {
    @MainActor func agentTools() -> [AgentTool] { [] }

    @MainActor func agentToolFactories() -> [AnyAgentToolFactory] { [] }
}
