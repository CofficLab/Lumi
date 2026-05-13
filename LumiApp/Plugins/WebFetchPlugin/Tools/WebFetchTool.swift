import Foundation
import MagicKit
import WebFetchKit

/// 网页抓取工具
///
/// 从指定 URL 抓取内容并转换为 Markdown 格式。
/// 支持处理 HTML、纯文本、JSON 等多种内容类型。
struct WebFetchTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose: Bool = false
    
    let name = "web_fetch"
    let description = """
Fetch and extract content from a URL. Converts HTML to Markdown format automatically.
Use this tool to retrieve web pages, documentation, or any publicly accessible HTTP content.

Note: This tool does NOT work with authenticated/private URLs (requires login, cookies, etc.).

Supported content types:
- HTML pages → converted to Markdown
- JSON → formatted as code block
- Plain text → returned directly
- Binary files (PDF, images) → returns file info and saves to temp directory
"""
    
    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "url": [
                    "type": "string",
                    "description": "The URL to fetch content from (must be a valid HTTP/HTTPS URL)"
                ],
                "prompt": [
                    "type": "string",
                    "description": "Optional: A prompt to process/extract specific information from the fetched content. If provided, the content will be summarized or filtered based on this prompt."
                ]
            ],
            "required": ["url"]
        ]
    }
    
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }
    
    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let urlString = arguments["url"]?.value as? String else {
            return "Error: Missing required 'url' parameter"
        }
        
        let prompt = arguments["prompt"]?.value as? String
        let service = WebFetchService()
        return await service.fetch(urlString: urlString, prompt: prompt)
    }
}
