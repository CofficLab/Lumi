import Foundation
import Testing
@testable import PluginConversationInput

/// 输入框拖放时**非文件 URL** 的处理。
///
/// ## 回归背景（真实用户缺陷）
///
/// 把一个 `mailto:` 链接拖进输入框，链接被当成文件附件去读取，用户看到的
/// 是一条「附件读取失败」错误，而不是链接本身。
///
/// 根因：输入框的 `performDragOperation` 把 pasteboard 里的**每一个** `NSURL`
/// 都交给附件链，既没有限制 `isFileURL`，也无条件地把这次拖放标记为已处理。
/// `https:` 链接同样被这条分支吞掉，进入远程数据读取。
///
/// 另一条拖放入口（`DroppedItemResolver`）本来就只接受本地文件 URL，
/// 两个入口的行为因此不一致。
@MainActor
@Suite("输入框拖放的非文件 URL")
struct ChatInputNonFileURLDropTests {

    // MARK: - 分流规则

    @Test("mailto 链接不进入附件链")
    func mailtoLinkIsRejected() async {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        viewModel.attach(droppedURL: URL(string: "mailto:user@example.com")!)

        await awaitSettle()

        #expect(capability.pendingFileAttachments.isEmpty)
        #expect(capability.pendingImageAttachments.isEmpty)
        #expect(capability.errorMessage == nil)
    }

    @Test("https 链接不进入附件链")
    func httpsLinkIsRejected() async {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        viewModel.attach(droppedURL: URL(string: "https://example.com/page")!)

        await awaitSettle()

        #expect(capability.pendingFileAttachments.isEmpty)
        #expect(capability.pendingImageAttachments.isEmpty)
        #expect(capability.errorMessage == nil)
    }

    @Test("非文件 URL 也不会被当成目录插入文本")
    func nonFileURLDoesNotInsertDirectoryPath() async {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        viewModel.attach(droppedURL: URL(string: "mailto:user@example.com")!)

        await awaitSettle()

        #expect(viewModel.pendingBlock == nil)
    }

    // MARK: - 拖放入口

    @Test("输入框的拖放只把本地文件交给附件处理器")
    func editorOnlyRoutesLocalFilesToAttachmentHandler() {
        let fileURL = URL(fileURLWithPath: "/tmp/notes.txt")
        let remoteURL = URL(string: "https://example.com/page")!

        #expect(ChatInputEditorRules.isFileAttachmentURL(fileURL))
        #expect(!ChatInputEditorRules.isFileAttachmentURL(remoteURL))
        #expect(!ChatInputEditorRules.isFileAttachmentURL(URL(string: "mailto:a@b.com")!))
    }
}
