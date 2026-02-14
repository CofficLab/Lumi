
import Foundation

struct MCPMarketplaceItem: Identifiable, Codable, Sendable {
    var id: String { name }
    let name: String
    let description: String
    let iconName: String
    let command: String
    let args: [String]
    let requiredEnvVars: [String] // List of env var keys that user needs to provide (e.g. "Z_AI_API_KEY")
    let documentationURL: String?
}

final class MCPMarketplace: Sendable {
    static let shared = MCPMarketplace()
    
    let items: [MCPMarketplaceItem] = [
        MCPMarketplaceItem(
            name: "Vision MCP",
            description: "Empower your agent with visual capabilities using Zhipu GLM-4V. Supports image analysis, UI-to-code, and more.",
            iconName: "eye.fill",
            command: "npx",
            args: ["-y", "@z_ai/mcp-server"],
            requiredEnvVars: ["Z_AI_API_KEY"],
            documentationURL: "https://docs.bigmodel.cn/cn/coding-plan/mcp/vision-mcp-server"
        )
        // Future items can be added here
    ]
}
