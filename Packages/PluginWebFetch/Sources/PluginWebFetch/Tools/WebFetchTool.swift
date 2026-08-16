import AgentToolKit
import Foundation

/// 网页抓取工具（KernelCore 体系）
///
/// 从指定 URL 抓取内容并转换为 Markdown 格式。支持处理 HTML、纯文本、JSON 等内容。
///
/// 由旧版 `LumiAgentTool` 迁移为 `SuperAgentTool`；`kernel.network` 依赖改为
/// `WebFetchRuntime`（主插件 onBoot 注入 fetcher），移除 `kernel.checkCancellation()`。
public struct WebFetchTool: SuperAgentTool {
    public let name = "web_fetch"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        """
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

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "url": [
                    "type": "string",
                    "description": "The URL to fetch content from (must be a valid HTTP/HTTPS URL)",
                ],
                "prompt": [
                    "type": "string",
                    "description": "Optional: A prompt to process/extract specific information from the fetched content. If provided, the content will be summarized or filtered based on this prompt.",
                ],
            ],
            "required": ["url"],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "抓取网页内容"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let urlString = arguments["url"]?.value as? String else {
            return "Error: Missing required 'url' parameter"
        }

        let prompt = arguments["prompt"]?.value as? String
        guard let fetcher = await MainActor.run(body: { WebFetchRuntime.fetcher }) else {
            return "Error: Network service is unavailable."
        }
        let service = WebFetchService(fetcher: fetcher)
        let result = await service.fetch(urlString: urlString, prompt: prompt)
        return result
    }
}
