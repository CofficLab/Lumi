import Foundation
import MCP

public struct MCPDiscoveredTool: @unchecked Sendable {
    public let serverName: String
    public let client: Client
    public let tool: MCP.Tool

    public init(serverName: String, client: Client, tool: MCP.Tool) {
        self.serverName = serverName
        self.client = client
        self.tool = tool
    }

    public var adaptedName: String {
        let safeServerName = serverName
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
        return "mcp__\(safeServerName)__\(tool.name)"
    }
}
