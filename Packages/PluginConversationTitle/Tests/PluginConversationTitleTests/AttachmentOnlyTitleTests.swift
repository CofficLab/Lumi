import Foundation
import KernelCore
import ProviderMessage
import Testing

@testable import PluginConversationTitle

/// 回归 #652：只有附件、正文为空的合法首条用户消息也能得到标题。
///
/// 发送端允许空正文 + 附件的消息，而两条标题路径都曾以「正文非空」为前提：
/// 实时生成在入口处跳过空正文，回填依赖 blank-filter 的 `firstUserMessage`
/// （同样跳过空正文），对话因此永久停在 Untitled。修复后标题素材退回到
/// 附件文件名——与正文占位标题同理，用户自己提供的内容优于通用占位符。
@Suite("纯附件首条消息的标题")
@MainActor
struct AttachmentOnlyTitleTests {

    // MARK: - Helpers

    private func makeService(
        messages: TitleTestDoubles.StubMessageManager,
        conversations: TitleTestDoubles.StubConversationManager,
        llm: TitleTestDoubles.StubLLMManager
    ) -> TitleService {
        TitleService(
            kernel: KernelCoreContainer(),
            conversations: conversations,
            messages: messages,
            llmProvider: llm
        )
    }

    /// 空正文 + 附件 metadata 的用户消息。
    private func attachmentOnlyMessage(
        in conversationID: UUID,
        fileNames: [String] = [],
        imageNames: [String] = []
    ) -> Message {
        var message = Message(conversationID: conversationID, role: .user, content: "  \n ")
        var metadata: [String: String] = [:]
        if !fileNames.isEmpty {
            metadata.merge(UserAttachmentMetadata.encodeFileAttachments(
                fileNames.map { UserFileAttachment(fileName: $0, mimeType: "application/pdf") }
            )) { current, _ in current }
        }
        if !imageNames.isEmpty {
            metadata.merge(UserAttachmentMetadata.encodeImageAttachments(
                imageNames.map { UserImageAttachment(mimeType: "image/png", base64Data: "", fileName: $0) }
            )) { current, _ in current }
        }
        message.metadata = metadata
        return message
    }

    /// 事件回调内部是 `Task { @MainActor }`，需要让出执行权等它跑完。
    private func settle() async {
        for _ in 0..<10 { await Task.yield() }
    }

    // MARK: - titleSource 素材选取

    @Test("标题素材正文优先，空正文退回附件文件名")
    func titleSourcePrefersContentThenAttachmentNames() {
        var message = Message(conversationID: UUID(), role: .user, content: "  排查登录超时  ")
        #expect(TitleService.titleSource(for: message) == "排查登录超时")

        message.content = ""
        message.metadata = UserAttachmentMetadata.encodeFileAttachments([
            UserFileAttachment(fileName: "a.pdf", mimeType: "application/pdf"),
            UserFileAttachment(fileName: "b.png", mimeType: "image/png"),
        ])
        #expect(TitleService.titleSource(for: message) == "a.pdf, b.png")
    }

    @Test("全部附件都匿名时标题素材为空")
    func titleSourceIsEmptyForAnonymousAttachments() {
        var message = Message(conversationID: UUID(), role: .user, content: "")
        message.metadata = UserAttachmentMetadata.encodeImageAttachments([
            UserImageAttachment(mimeType: "image/png", base64Data: "aGk=")
        ])
        #expect(TitleService.titleSource(for: message).isEmpty)
    }

    // MARK: - 实时生成

    @Test("纯附件首条消息触发标题生成，LLM 收到文件名")
    func generatesTitleFromAttachmentFileNames() async {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        let messages = TitleTestDoubles.StubMessageManager()
        let llm = TitleTestDoubles.StubLLMManager(responseContent: "设计稿评审")

        let service = makeService(messages: messages, conversations: conversations, llm: llm)
        defer { service.stop() }

        messages.emitInserted(attachmentOnlyMessage(in: conversationID, fileNames: ["设计稿-v2.pdf"]))
        await settle()

        #expect(llm.receivedRequests.count == 1)
        let request = try! #require(llm.receivedRequests.first)
        let user = try! #require(request.messages.last)
        #expect(user.content.contains("设计稿-v2.pdf"))
        #expect(conversations.title(of: conversationID) == "设计稿评审")
    }

    @Test("LLM 失败时回退到文件名占位标题")
    func fallsBackToFileNamePlaceholderWhenLLMFails() async {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        let messages = TitleTestDoubles.StubMessageManager()
        let llm = TitleTestDoubles.StubLLMManager(
            completionError: StubLLMError(reason: "network down")
        )

        let service = makeService(messages: messages, conversations: conversations, llm: llm)
        defer { service.stop() }

        messages.emitInserted(attachmentOnlyMessage(in: conversationID, fileNames: ["季度报告.xlsx"]))
        await settle()

        #expect(llm.receivedRequests.count == 1)
        #expect(conversations.title(of: conversationID) == "季度报告.xlsx")
    }

    @Test("全部附件匿名时仍按空白消息跳过")
    func anonymousAttachmentsAreSkipped() async {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        let messages = TitleTestDoubles.StubMessageManager()
        let llm = TitleTestDoubles.StubLLMManager()

        let service = makeService(messages: messages, conversations: conversations, llm: llm)
        defer { service.stop() }

        // 粘贴的图片没有文件名：没有可用素材，与空白消息同样跳过。
        var message = Message(conversationID: conversationID, role: .user, content: "")
        message.metadata = UserAttachmentMetadata.encodeImageAttachments([
            UserImageAttachment(mimeType: "image/png", base64Data: "aGk=")
        ])
        messages.emitInserted(message)
        await settle()

        #expect(llm.receivedRequests.isEmpty)
        #expect(conversations.titleUpdateRequests.isEmpty)
    }

    /// 标题已在首条附件消息上生成后，后续消息（无论纯附件还是文本）都不再重新生成。
    @Test("首条附件消息定题后，后续消息不重新生成")
    func laterMessagesDoNotRegenerateAfterAttachmentFirst() async {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        let messages = TitleTestDoubles.StubMessageManager()
        let llm = TitleTestDoubles.StubLLMManager(responseContent: "设计稿评审")

        let service = makeService(messages: messages, conversations: conversations, llm: llm)
        defer { service.stop() }

        messages.emitInserted(attachmentOnlyMessage(in: conversationID, fileNames: ["设计稿-v2.pdf"]))
        await settle()
        #expect(llm.receivedRequests.count == 1)

        // 后续纯附件消息：扫描到的首条可产标题消息不是它，不重复生成。
        messages.emitInserted(attachmentOnlyMessage(in: conversationID, fileNames: ["第二份.pdf"]))
        await settle()
        // 后续文本消息：占位替换规则只认首条素材，不重复生成。
        messages.emitInserted(Message(conversationID: conversationID, role: .user, content: "第二条文本"))
        await settle()

        #expect(llm.receivedRequests.count == 1)
        #expect(conversations.titleUpdateRequests.count == 1)
        #expect(conversations.title(of: conversationID) == "设计稿评审")
    }

    // MARK: - 启动回填

    @Test("回填为纯附件对话补写文件名占位标题")
    func backfillsAttachmentOnlyConversation() async {
        let conversationID = UUID()
        let conversations = TitleTestDoubles.StubConversationManager()
        conversations.appendSummary(id: conversationID, title: nil)
        let messages = TitleTestDoubles.StubMessageManager(messages: [
            attachmentOnlyMessage(in: conversationID, fileNames: ["架构评审记录.pdf"])
        ])
        let llm = TitleTestDoubles.StubLLMManager()

        let service = makeService(messages: messages, conversations: conversations, llm: llm)
        defer { service.stop() }

        let backfilled = await service.backfillUntitledConversations()

        #expect(backfilled == 1)
        #expect(conversations.title(of: conversationID) == "架构评审记录.pdf")
        #expect(llm.receivedRequests.isEmpty, "回填不应消耗 LLM 额度")
    }
}
