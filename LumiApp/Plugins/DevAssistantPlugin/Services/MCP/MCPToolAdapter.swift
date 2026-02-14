
import Foundation
import MCP
import OSLog

/// Adapts an MCP Tool to the AgentTool protocol
final class MCPToolAdapter: AgentTool, @unchecked Sendable {
    let client: Client
    let mcpTool: MCP.Tool
    
    init(client: Client, tool: MCP.Tool) {
        self.client = client
        self.mcpTool = tool
    }
    
    var name: String {
        mcpTool.name
    }
    
    var description: String {
        mcpTool.description ?? ""
    }
    
    var inputSchema: [String: Any] {
        // Convert MCP.JSONSchema to [String: Any]
        guard let data = try? JSONEncoder().encode(mcpTool.inputSchema),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }
    
    func execute(arguments: [String: Any]) async throws -> String {
        // Convert arguments dictionary to MCP.Value
        let mcpArguments: [String: Value]
        do {
            let data = try JSONSerialization.data(withJSONObject: arguments)
            mcpArguments = try JSONDecoder().decode([String: Value].self, from: data)
        } catch {
            os_log(.error, "Failed to convert arguments for tool \(self.name): \(error.localizedDescription)")
            throw error
        }
        
        let result = try await client.callTool(name: name, arguments: mcpArguments)
        
        if result.isError ?? false {
            let errorMessage = result.content.compactMap { content -> String? in
                if case .text(let text) = content { return text }
                return nil
            }.joined(separator: "\n")
            throw NSError(domain: "MCPToolAdapter", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage.isEmpty ? "Unknown error from tool" : errorMessage])
        }
        
        // Combine content into string
        return result.content.compactMap { content -> String? in
            switch content {
            case .text(let text):
                return text
            case .image(_, let mimeType, _):
                return "[Image: \(mimeType)]"
            case .resource(let uri, _, _):
                return "[Resource: \(uri)]"
            @unknown default:
                return nil
            }
        }.joined(separator: "\n")
    }
}
