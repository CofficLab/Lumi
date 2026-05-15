import Foundation
import MagicKit
import WebFetchKit

/// 网页抓取工具
///
/// 从指定 URL 抓取内容并转换为 Markdown 格式。
/// 支持处理 HTML、纯文本、JSON 等多种内容类型。
struct WebFetchTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose: Bool = true
    
    let name = "web_fetch"
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "Fetch and extract content from a URL. Converts HTML to Markdown format automatically.\nUse this tool to retrieve web pages, documentation, or any publicly accessible HTTP content.\n\nNote: This tool does NOT work with authenticated/private URLs (requires login, cookies, etc.).\n\nSupported content types:\n- HTML pages → converted to Markdown\n- JSON → formatted as code block\n- Plain text → returned directly\n- Binary files (PDF, images) → returns file info and saves to temp directory"
        case .english:
            return     """
Fetch and extract content from a URL. Converts HTML to Markdown format automatically.
Use this tool to retrieve web pages, documentation, or any publicly accessible HTTP content.

Note: This tool does NOT work with authenticated/private URLs (requires login, cookies, etc.).

Supported content types:
- HTML pages → converted to Markdown
- JSON → formatted as code block
- Plain text → returned directly
- Binary files (PDF, images) → returns file info and saves to temp directory
"""
        }
    }
    
    func inputSchema(for language: LanguagePreference) -> [String: Any] {
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
        try await executeFetch(arguments: arguments, context: nil)
    }

    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        return try await executeFetch(arguments: arguments, context: context)
    }

    private func executeFetch(arguments: [String: ToolArgument], context: ToolExecutionContext?) async throws -> String {
        guard let urlString = arguments["url"]?.value as? String else {
            return "Error: Missing required 'url' parameter"
        }
        
        let prompt = arguments["prompt"]?.value as? String
        let service = WebFetchService()
        try context?.checkCancellation()
        let result = await service.fetch(urlString: urlString, prompt: prompt)
        try context?.checkCancellation()
        return result
    }
}
