import Foundation
import KitAgentTool

/// 截取当前页面并把图片返回给模型。
///
/// 文本快照看不出来的信息（布局、图标、canvas、颜色、图片内容），
/// 多模态模型可以直接从截图里读出来。
public struct BrowserScreenshotTool: SuperAgentTool {
    private let sessions: BrowserSessionManager
    public let name = "browser_screenshot"

    public init(sessions: BrowserSessionManager) { self.sessions = sessions }

    public func description(for language: LanguagePreference) -> String {
        BrowserToolText.screenshotDescription(language)
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "full_page": [
                    "type": "boolean",
                    "description": BrowserToolText.fullPageProperty(language),
                ],
            ],
        ]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let fullPage = (arguments["full_page"]?.value as? Bool) ?? false
        return fullPage ? BrowserToolText.displayFullPageScreenshot(.current) : BrowserToolText.displayScreenshot(.current)
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    public var executionCapability: ToolExecutionCapability { .parallelReadOnly }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        throw ToolExecutionError.executionFailed(toolName: name, reason: "Browser tools require conversation execution context.")
    }

    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        let fullPage = (arguments["full_page"]?.value as? Bool) ?? false
        let data = try await sessions.screenshot(
            fullPage: fullPage,
            conversationID: context.conversationID
        )
        let attachment = ImageAttachment(
            data: data,
            mimeType: "image/png",
            fileName: fullPage ? "browser-full-page.png" : "browser-screenshot.png"
        )
        return ToolCallResult(
            content: fullPage
                ? "Captured a full-page screenshot of the current page."
                : "Captured a screenshot of the visible page.",
            images: [attachment]
        )
    }
}
