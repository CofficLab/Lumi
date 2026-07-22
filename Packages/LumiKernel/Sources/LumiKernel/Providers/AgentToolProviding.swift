import Foundation

public typealias _AgentTool = LumiAgentTool
public typealias _SubAgentDefinition = LumiSubAgentDefinition

@MainActor
public protocol AgentToolProviding: AnyObject {
    func allAgentTools() -> [any LumiAgentTool]
    func add(_ tool: any LumiAgentTool)
    func remove(id: String)
    func allSubAgents() -> [LumiSubAgentDefinition]
    func addSubAgent(_ subAgent: LumiSubAgentDefinition)
}
