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
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return """
从 URL 抓取并提取内容。会自动将 HTML 转换为 Markdown 格式。
使用此工具获取网页、文档或任何公开可访问的 HTTP 内容。

注意：此工具不适用于需要登录、Cookie 等认证信息的私有 URL。

支持的内容类型：
- HTML 页面 → 转换为 Markdown
- JSON → 格式化为代码块
- 纯文本 → 直接返回
- 二进制文件（PDF、图片）→ 返回文件信息并保存到临时目录
"""
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
