import Combine
import Foundation

@MainActor
public final class AgentToolComponent: ObservableObject {
    public init() {}

    public func buildToolSet(
        builtInTools: [any LumiAgentTool],
        pluginTools: [any LumiAgentTool] = [],
        environment: (any ToolServiceEnvironment)? = nil
    ) -> ToolService {
        let allTools = builtInTools + pluginTools
        return ToolService(tools: allTools, environment: environment)
    }
}
