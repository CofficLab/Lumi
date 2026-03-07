
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
    var transportType: MCPTransportType = .stdio
    var url: String?
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
            documentationURL: "https://docs.bigmodel.cn/cn/coding-plan/mcp/vision-mcp-server",
            transportType: .stdio
        ),
        MCPMarketplaceItem(
            name: "Search MCP",
            description: "Real-time web search capabilities for your agent.",
            iconName: "magnifyingglass",
            command: "",
            args: [],
            requiredEnvVars: ["Z_AI_API_KEY"],
            documentationURL: "https://docs.bigmodel.cn/cn/coding-plan/mcp/search-mcp-server",
            transportType: .sse,
            url: "https://open.bigmodel.cn/api/mcp/web_search_prime/sse"
        ),
        MCPMarketplaceItem(
            name: "Reader MCP",
            description: "Extract content and structured data from any webpage.",
            iconName: "doc.text.viewfinder",
            command: "",
            args: [],
            requiredEnvVars: ["Z_AI_API_KEY"],
            documentationURL: "https://docs.bigmodel.cn/cn/coding-plan/mcp/reader-mcp-server",
            transportType: .sse,
            url: "https://open.bigmodel.cn/api/mcp/web_reader/sse"
        ),
        MCPMarketplaceItem(
            name: "ZRead MCP",
            description: "Access knowledge and code from GitHub repositories.",
            iconName: "book.closed",
            command: "",
            args: [],
            requiredEnvVars: ["Z_AI_API_KEY"],
            documentationURL: "https://docs.bigmodel.cn/cn/coding-plan/mcp/zread-mcp-server",
            transportType: .sse,
            url: "https://open.bigmodel.cn/api/mcp/zread/sse"
        )
    ]
}
