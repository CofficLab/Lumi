import Foundation
import MagicKit

/// 网页搜索工具
///
/// 提供网页搜索功能。
/// 该工具的存在主要是为了满足阿里云 Qwen 系列模型的 Function Calling 限制：
/// 当使用 web_extractor 或 web_fetch 工具时，必须同时声明 web_search 工具。
///
/// 当前为轻量级实现，仅返回提示信息，可根据需求后续接入真实搜索 API。
struct WebSearchTool: AgentTool, SuperLog {
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose: Bool = false
    
    let name = "web_search"
    let description = """
Search the web for real-time information.
Use this tool to find current information, news, or specific data from the internet.

Note: This tool is often required to be used alongside web_fetch or web_extractor by certain AI models (e.g., Qwen).
"""
    
    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": "The search query to find information on the web"
                ]
            ],
            "required": ["query"]
        ]
    }
    
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }
    
    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let query = arguments["query"]?.value as? String else {
            return "Error: Missing required 'query' parameter"
        }
        
        if Self.verbose {
            AppLogger.core.info("\(self.t)🔍 Searching for: \(query)")
        }
        
        // 当前实现为轻量级占位，满足 Qwen 模型参数校验要求
        // 如需真实搜索功能，可在此接入 Tavily、Bing 或 DuckDuckGo 等 API
        return """
## Web Search Result

**Query**: \(query)
**Status**: Web search tool is currently in placeholder mode.

Note: This tool exists to satisfy API requirements for models like Qwen that require web_search to be present alongside web_fetch. 
To perform actual searches, please use `web_fetch` with a search engine URL (e.g., https://www.google.com/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""))
"""
    }
}
