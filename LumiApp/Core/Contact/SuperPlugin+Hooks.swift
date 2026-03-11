import Foundation

// MARK: - Agent Tools & Worker Default Implementation

extension SuperPlugin {
    @MainActor func agentTools() -> [AgentTool] { [] }

    @MainActor func agentToolFactories() -> [AnyAgentToolFactory] { [] }

    @MainActor func workerAgentDescriptors() -> [WorkerAgentDescriptor] { [] }

    @MainActor func toolPresentationDescriptors() -> [ToolPresentationDescriptor] { [] }

    @MainActor func mcpServerConfigs() -> [MCPServerConfig] { [] }
}
