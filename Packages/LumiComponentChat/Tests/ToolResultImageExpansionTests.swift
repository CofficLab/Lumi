import Foundation
import LumiCoreKit
import Testing
@testable import LumiChatKit

@MainActor
struct ToolResultImageExpansionTests {
    @Test func expandingToolResultInjectsImagesIntoMetadata() throws {
        let conversationID = UUID()
        let image = LumiImageAttachment(
            mimeType: "image/png",
            base64Data: Data([0x89, 0x50, 0x4E, 0x47]).base64EncodedString(),
            fileName: "screenshot.png"
        )
        let toolCall = LumiToolCall(
            id: "call-1",
            name: "read_file",
            arguments: "{}",
            result: LumiToolResult(content: "已加载图片：screenshot.png", imageAttachments: [image])
        )
        let assistant = LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            toolCalls: [toolCall]
        )

        let expanded = ChatService.messagesByExpandingToolResults([assistant])

        // assistant 消息保留，且在其后展开一条 tool 消息
        #expect(expanded.count == 2)
        let toolMessage = try #require(expanded.last)
        #expect(toolMessage.role == .tool)
        #expect(toolMessage.toolCallID == "call-1")

        // 图片被注入 metadata，复用与用户附图相同的视觉通道
        let metadata = toolMessage.metadata
        #expect(metadata["hasImages"] == "true")
        let encoded = try #require(metadata["imageAttachments"])
        let decoded = try JSONDecoder().decode([LumiImageAttachment].self, from: Data(encoded.utf8))
        #expect(decoded.count == 1)
        #expect(decoded.first?.mimeType == "image/png")
        #expect(decoded.first?.fileName == "screenshot.png")
    }

    @Test func expandingTextOnlyToolResultLeavesMetadataEmpty() {
        let conversationID = UUID()
        let toolCall = LumiToolCall(
            id: "call-2",
            name: "shell",
            arguments: "{}",
            result: LumiToolResult(content: "command output")
        )
        let assistant = LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            toolCalls: [toolCall]
        )

        let expanded = ChatService.messagesByExpandingToolResults([assistant])
        let toolMessage = expanded.last
        #expect(toolMessage?.metadata.isEmpty == true)
    }
}
