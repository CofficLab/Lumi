import Foundation
import KernelCore
import ProviderMessage
import Testing
@testable import PluginConversationExport

/// 回归 #859：HTML 导出把消息与工具结果的首尾空白裁掉了。
///
/// `nonempty` 助手原本返回的是**裁剪后**的字符串。导出的正文、推理、工具参数、
/// 工具结果与附件文件体都是预排版内容，首尾的缩进、空格与换行属于原文的一部分。
/// 裁剪之后即使 CSS 已经用 `white-space: pre-wrap` 也无法恢复，用户拿到的导出
/// 与应用里的原文对不上，且丢失的是不可见字符，很难被察觉。
@MainActor
@Suite("HTML 导出的空白保留")
struct ConversationExportWhitespaceTests {

    /// 工具结果里常见的「带缩进的多行输出」。
    private let indentedToolResult = "\n    first\nsecond  \n"

    @Test("工具结果的首尾空白原样保留")
    func toolResultKeepsSurroundingWhitespace() throws {
        let html = try exportHTML(
            message: Message(
                conversationID: UUID(),
                role: .assistant,
                content: "",
                toolCalls: [
                    MessageToolCall(
                        id: "call-1",
                        name: "shell",
                        arguments: "{\"cmd\":\"ls\"}",
                        result: MessageToolResult(content: indentedToolResult)
                    )
                ]
            )
        )

        // 原文：前导换行 + 四个空格缩进 + 尾随的两个空格与换行。
        #expect(html.contains("<div class=\"detail-content\">\n    first\nsecond  \n</div>"))
    }

    @Test("消息正文的首尾空白原样保留")
    func messageContentKeepsSurroundingWhitespace() throws {
        let html = try exportHTML(
            message: Message(
                conversationID: UUID(),
                role: .user,
                content: "  hello  \n"
            )
        )

        #expect(html.contains("<div class=\"content\">  hello  \n</div>"))
    }

    @Test("推理内容与工具参数的首尾空白原样保留")
    func reasoningAndArgumentsKeepSurroundingWhitespace() throws {
        let html = try exportHTML(
            message: Message(
                conversationID: UUID(),
                role: .assistant,
                content: "answer",
                reasoningContent: "\n  think  \n",
                toolCalls: [
                    MessageToolCall(
                        id: "call-1",
                        name: "shell",
                        arguments: "  {\"cmd\":\"ls\"}  "
                    )
                ]
            )
        )

        #expect(html.contains("<div class=\"detail-content\">\n  think  \n</div>"))
        #expect(html.contains("<pre>  {&quot;cmd&quot;:&quot;ls&quot;}  </pre>"))
    }

    @Test("附件文件体的首尾空白原样保留")
    func attachmentFileBodyKeepsSurroundingWhitespace() throws {
        var metadata = UserAttachmentMetadata.encodeFileAttachments([
            UserFileAttachment(
                fileName: "notes.txt",
                mimeType: "text/plain",
                base64Data: "aGVsbG8=",
                textContent: "\n  body  \n"
            ),
        ])

        let html = try exportHTML(
            message: Message(
                conversationID: UUID(),
                role: .user,
                content: "",
                metadata: metadata
            )
        )
        metadata.removeAll()

        #expect(html.contains("<pre>\n  body  \n</pre>"))
    }

    @Test("纯空白的内容仍然被当作空内容，不渲染正文")
    func whitespaceOnlyContentIsStillTreatedAsEmpty() throws {
        let html = try exportHTML(
            message: Message(
                conversationID: UUID(),
                role: .user,
                content: "   \n  "
            )
        )

        #expect(html.contains("<span class=\"empty\">No text content</span>"))
    }

    // MARK: - Helpers

    /// 导出只有一条消息的快照并返回 HTML 文本。
    private func exportHTML(message: Message) throws -> String {
        let snapshot = ConversationExportSnapshot(
            conversationID: message.conversationID,
            title: "Whitespace",
            createdAt: nil,
            projectPath: nil,
            providerID: nil,
            modelName: nil,
            messages: [message],
            exportedAt: Date(timeIntervalSince1970: 0)
        )

        return try #require(String(data: ConversationHTMLExporter.export(snapshot).data, encoding: .utf8))
    }
}
