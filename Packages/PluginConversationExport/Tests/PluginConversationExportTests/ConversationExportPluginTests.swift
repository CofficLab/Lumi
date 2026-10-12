import Foundation
import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginConversationExport

@MainActor
struct ConversationExportPluginTests {
    @Test("插件向 ChatToolbar 注册并撤回导出入口")
    func registersToolbarItem() throws {
        let kernel = KernelCoreContainer()
        let chat = DefaultChatSectionProviding()
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any ConversationManaging).self, conversations)
        try kernel.registerProvider((any MessageManaging).self, messages)

        let plugin = ConversationExportPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(chat.barItems.map(\.id) == ["com.coffic.lumi.plugin.conversation-export.toolbar"])
        #expect(chat.barItems.first?.order == 90)

        try plugin.onShutdown(kernel: kernel)
        #expect(chat.barItems.isEmpty)
    }

    @Test("HTML 导出按时间排序并转义不可信内容")
    func exportsSafeOrderedHTML() throws {
        let conversationID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let later = Message(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            conversationID: conversationID,
            role: .assistant,
            content: "回答 & 完成",
            createdAt: Date(timeIntervalSince1970: 20),
            modelName: "step-5-preview",
            reasoningContent: "reason <private>"
        )
        let earlier = Message(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            conversationID: conversationID,
            role: .user,
            content: "<script>alert(\"x\")</script>",
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let snapshot = ConversationExportSnapshot(
            conversationID: conversationID,
            title: "设计 <讨论>",
            createdAt: Date(timeIntervalSince1970: 1),
            projectPath: "/tmp/<project>",
            providerID: "stepfun-platform",
            modelName: "step-5-preview",
            messages: [later, earlier],
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let result = ConversationHTMLExporter.export(snapshot)
        let html = try #require(String(data: result.data, encoding: .utf8))

        #expect(html.contains("&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;"))
        #expect(!html.contains("<script>"))
        #expect(html.contains("reason &lt;private&gt;"))
        #expect(html.contains("Project: /tmp/&lt;project&gt;"))
        #expect(try #require(html.range(of: "data-role=\"user\"")?.lowerBound) < #require(html.range(of: "data-role=\"assistant\"")?.lowerBound))
        #expect(result.suggestedFilename == "设计-讨论-20231114-221320.html")
    }

    @Test("HTML 导出保留工具结果和安全的内嵌图片")
    func exportsToolDetailsAndImages() throws {
        let conversationID = UUID()
        var metadata = UserAttachmentMetadata.encodeImageAttachments([
            UserImageAttachment(mimeType: "image/png", base64Data: "aGVsbG8=", fileName: "用户截图.png"),
        ])
        metadata.merge(
            UserAttachmentMetadata.encodeFileAttachments([
                UserFileAttachment(
                    fileName: "notes.txt",
                    mimeType: "text/plain",
                    base64Data: "aGVsbG8=",
                    textContent: "<notes>"
                ),
            ]),
            uniquingKeysWith: { _, new in new }
        )
        let call = MessageToolCall(
            id: "call-1",
            name: "view_image",
            arguments: "{\"path\":\"<image>\"}",
            result: MessageToolResult(
                content: "完成 <ok>",
                imageAttachments: [MessageImageAttachment(data: "aGVsbG8=", mimeType: "image/png")]
            ),
            displayDescription: "查看图片"
        )
        let message = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            metadata: metadata,
            toolCalls: [call]
        )
        let snapshot = ConversationExportSnapshot(
            conversationID: conversationID,
            title: "Tools",
            createdAt: nil,
            projectPath: nil,
            providerID: nil,
            modelName: nil,
            messages: [message],
            exportedAt: Date(timeIntervalSince1970: 0)
        )

        let html = try #require(String(data: ConversationHTMLExporter.export(snapshot).data, encoding: .utf8))
        #expect(html.contains("Tool calls (1)"))
        #expect(html.contains("{&quot;path&quot;:&quot;&lt;image&gt;&quot;}"))
        #expect(html.contains("完成 &lt;ok&gt;"))
        #expect(html.contains("data:image/png;base64,aGVsbG8="))
        #expect(html.contains("Attachments (2)"))
        #expect(html.contains("用户截图.png"))
        #expect(html.contains("download=\"notes.txt\""))
        #expect(html.contains("&lt;notes&gt;"))
    }
}
