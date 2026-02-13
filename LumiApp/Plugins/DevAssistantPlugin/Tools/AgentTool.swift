import Foundation

/// Protocol defining an agent tool that can be invoked by the LLM
protocol AgentTool: Sendable {
    /// The unique name of the tool (e.g., "read_file")
    var name: String { get }
    
    /// A description of what the tool does
    var description: String { get }
    
    /// The JSON schema for the tool's input parameters
    var inputSchema: [String: Any] { get }
    
    /// Executes the tool with the given arguments
    /// - Parameter arguments: A dictionary of arguments matching the input schema
    /// - Returns: The result of the execution as a String
    func execute(arguments: [String: Any]) async throws -> String
}

// Helper to define schema easily
struct ToolParam {
    let type: String
    let description: String
    let required: Bool
}
