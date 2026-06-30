import Foundation
import LumiCoreKit
import SuperLogKit

/// 网页抓取工具。
///
/// 从指定 URL 抓取内容并转换为 Markdown 格式。支持处理 HTML、纯文本、JSON 等内容。
public struct WebFetchTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🌐"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "web_fetch",
        displayName: "Web Fetch",
        description: """
        Fetch and extract content from a URL. Converts HTML to Markdown format automatically.
        Use this tool to retrieve web pages, documentation, or any publicly accessible HTTP content.

        Note: This tool does NOT work with authenticated/private URLs (requires login, cookies, etc.).

        Supported content types:
        - HTML pages → converted to Markdown
        - JSON → formatted as code block
        - Plain text → returned directly
        - Binary files (PDF, images) → returns file info and saves to temp directory
        """
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "url": .object([
                    "type": .string("string"),
                    "description": .string("The URL to fetch content from (must be a valid HTTP/HTTPS URL)"),
                ]),
                "prompt": .object([
                    "type": .string("string"),
                    "description": .string("Optional: A prompt to process/extract specific information from the fetched content. If provided, the content will be summarized or filtered based on this prompt."),
                ]),
            ]),
            "required": .array([.string("url")]),
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "抓取网页内容"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        try context.checkCancellation()
        return try await executeFetch(arguments: arguments, context: context)
    }

    private func executeFetch(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let urlString = arguments.string("url") else {
            return "Error: Missing required 'url' parameter"
        }

        let prompt = arguments.string("prompt")
        let service = WebFetchService()
        try context.checkCancellation()
        let result = await service.fetch(urlString: urlString, prompt: prompt)
        try context.checkCancellation()
        return result
    }
}
