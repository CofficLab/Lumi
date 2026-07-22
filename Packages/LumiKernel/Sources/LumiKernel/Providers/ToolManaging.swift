import Foundation

public typealias _AgentTool = LumiAgentTool
public typealias _SubAgentDefinition = LumiSubAgentDefinition

@MainActor
public protocol ToolManaging: AnyObject {
    func allAgentTools() -> [any LumiAgentTool]
    func add(_ tool: any LumiAgentTool)
    func remove(id: String)
    func allSubAgents() -> [LumiSubAgentDefinition]
    func addSubAgent(_ subAgent: LumiSubAgentDefinition)
}
