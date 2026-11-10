import Foundation
import ProviderMessage
import ProviderMessageSender
import Testing
@testable import PluginConversationInput

/// `ConversationInputViewModel` 的附件生命周期与拖放。
///
/// 既有测试集中在「发送 / 停止」这条主链路（见 `SendActionBarViewModelTests` 与
/// `ConversationInputViewModelInputSyncTests`）。本套件补的是另一侧：
///
/// - **附件增删**：附件预览上的 ✕ 走 `removeImageAttachment` / `removeFileAttachment`，
///   它们只透传到能力层，删错 ID 不会报错也没人拦——正因如此更需要断言。
/// - **拖放分流**：目录 / 图片 / 普通文件三条路径的落点完全不同（插入文本 / 进图片池 /
///   进文件池），且异步读取失败必须落到错误提示而不是静默吞掉。
@MainActor
@Suite("ConversationInputViewModel 附件与拖放")
struct ConversationInputViewModelAttachmentTests {
    // MARK: - 附件移除

    @Test("移除图片附件按 ID 精确命中，其余保留")
    func removeImageAttachmentTargetsSingleID() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        let first = UserImageAttachment(mimeType: "image/png", base64Data: "AAAA")
        let second = UserImageAttachment(mimeType: "image/png", base64Data: "BBBB")
        capability.pendingImageAttachments = [first, second]

        viewModel.removeImageAttachment(id: first.id)
        viewModel.refresh()

        #expect(viewModel.imageAttachments.map(\.id) == [second.id])
        #expect(capability.pendingImageAttachments.map(\.id) == [second.id])
    }

    @Test("移除文件附件按 ID 精确命中，其余保留")
    func removeFileAttachmentTargetsSingleID() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        let first = UserFileAttachment(fileName: "a.txt", mimeType: "text/plain", textContent: "a")
        let second = UserFileAttachment(fileName: "b.txt", mimeType: "text/plain", textContent: "b")
        capability.pendingFileAttachments = [first, second]

        viewModel.removeFileAttachment(id: second.id)
        viewModel.refresh()

        #expect(viewModel.fileAttachments.map(\.id) == [first.id])
        #expect(capability.pendingFileAttachments.map(\.id) == [first.id])
    }

    @Test("移除不存在的附件 ID 是安全的空操作")
    func removingUnknownAttachmentIsNoOp() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        let kept = UserFileAttachment(fileName: "a.txt", mimeType: "text/plain", textContent: "a")
        capability.pendingFileAttachments = [kept]
        viewModel.refresh()

        viewModel.removeImageAttachment(id: UUID())
        viewModel.removeFileAttachment(id: UUID())
        viewModel.refresh()

        #expect(viewModel.fileAttachments.map(\.id) == [kept.id])
        #expect(viewModel.imageAttachments.isEmpty)
    }

    @Test("附件池变化同步刷新列表与可发送状态")
    func attachmentPoolChangeRefreshesState() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        #expect(!viewModel.hasAttachments)
        #expect(!viewModel.canSend)

        capability.pendingImageAttachments = [
            UserImageAttachment(mimeType: "image/png", base64Data: "AAAA")
        ]
        viewModel.refresh()

        #expect(viewModel.hasAttachments)
        // 正文为空但有附件 → 仍可发送。
        #expect(viewModel.canSend)

        capability.pendingImageAttachments = []
        viewModel.refresh()

        #expect(!viewModel.hasAttachments)
        #expect(!viewModel.canSend)
    }

    // MARK: - 拖放：目录 → 文本

    @Test("拖入目录把路径交给编辑器插入，不直接改写草稿正文")
    func droppingDirectoryQueuesPlainTextBlock() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)
        capability.text = "look at\n"
        viewModel.refresh()

        viewModel.insertDirectoryPath(URL(fileURLWithPath: "/tmp/pkg"))

        let block = try! #require(viewModel.pendingBlock)
        #expect(block.text == "/tmp/pkg")
        // 目录路径始终按纯文本插入，不能折叠成 chip。
        #expect(!block.shouldCollapse)
        // 正文只能由编辑器上报：直接写 binding 会让编辑器把已有 chip 拍平。
        #expect(viewModel.text == "look at\n")
        // 拖放会强制聚焦，用户可以直接继续写指令。
        #expect(capability.isInputFocused)
    }

    // MARK: - 拖放：图片 / 文件 → 挂起池

    @Test("拖入图片进入图片池并聚焦输入框")
    func droppingImageAttachesToImagePool() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("conversation-input-image-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("pixel.png")
        let png = try #require(Data(base64Encoded: attachmentTestPNGBase64))
        #expect(FileManager.default.createFile(atPath: fileURL.path, contents: png))

        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        viewModel.attachImage(fileURL)

        await waitUntil("图片附件未加入挂起池", timeout: .seconds(10)) {
            !capability.pendingImageAttachments.isEmpty
        }

        let attachment = try #require(capability.pendingImageAttachments.first)
        #expect(attachment.fileName == "pixel.png")
        // 扩展名决定 MIME，未知扩展名回落到 image/png。
        #expect(attachment.mimeType == "image/png")
        #expect(attachment.base64Data == png.base64EncodedString())
        #expect(capability.isInputFocused)
    }

    @Test("拖入非空但不可解码的图片时报错且不进图片池")
    func droppingCorruptImageSurfacesErrorAndSkipsPool() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("conversation-input-corrupt-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        // 扩展名像图片、字节非空，但内容无法解码。
        let fileURL = directory.appendingPathComponent("fake.png")
        #expect(
            FileManager.default.createFile(
                atPath: fileURL.path,
                contents: Data("definitely not a png".utf8)
            )
        )

        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        viewModel.attachImage(fileURL)

        await waitUntil("损坏图片未上报错误提示", timeout: .seconds(10)) {
            viewModel.errorMessage != nil
        }

        #expect(capability.pendingImageAttachments.isEmpty)
        let message = try #require(viewModel.errorMessage)
        #expect(message.contains("fake.png"))
    }

    @Test("拖入空文件不会进入图片池")
    func droppingEmptyImageIsIgnored() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("conversation-input-empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("empty.png")
        #expect(FileManager.default.createFile(atPath: fileURL.path, contents: Data()))

        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        viewModel.attachImage(fileURL)

        // 读取路径是异步的；等待一轮后仍应为空，且不产生错误提示。
        await awaitSettle()

        #expect(capability.pendingImageAttachments.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("拖入普通文件进入文件池并聚焦输入框")
    func droppingFileAttachesToFilePool() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("conversation-input-file-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("notes.txt")
        #expect(
            FileManager.default.createFile(
                atPath: fileURL.path,
                contents: Data("hello".utf8)
            )
        )

        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        viewModel.attachFile(fileURL)

        await waitUntil("文件附件未加入挂起池") {
            !capability.pendingFileAttachments.isEmpty
        }

        let attachment = try #require(capability.pendingFileAttachments.first)
        #expect(attachment.fileName == "notes.txt")
        #expect(attachment.mimeType == "text/plain")
        #expect(attachment.textContent == "hello")
        #expect(capability.isInputFocused)
    }

    @Test("拖入不可读文件时错误提示可见")
    func droppingUnreadableFileSurfacesError() async throws {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        // 指向不存在的路径，`UserFileAttachmentLoader.load` 必定抛错。
        viewModel.attachFile(
            URL(fileURLWithPath: "/tmp/definitely-missing-\(UUID().uuidString).txt")
        )

        await waitUntil("读取失败未上报错误提示") {
            viewModel.errorMessage != nil
        }

        #expect(capability.pendingFileAttachments.isEmpty)
    }

    @Test("错误提示可被显式清除")
    func dismissErrorClearsMessage() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        capability.errorMessage = "send failed"
        viewModel.refresh()
        #expect(viewModel.errorMessage == "send failed")

        viewModel.dismissError()

        #expect(viewModel.errorMessage == nil)
        #expect(capability.errorMessage == nil)
    }

    // MARK: - 发送即消费

    @Test("带附件发送在编码完成前消费附件，提交成功前不清空正文")
    func sendWithAttachmentsConsumesThemBeforeEncoding() async {
        let capability = SendActionBarTestCapability()
        let file = UserFileAttachment(fileName: "notes.txt", mimeType: "text/plain", textContent: "notes")
        capability.pendingFileAttachments = [file]
        capability.text = "first"
        capability.commit = MessageSendCommit(conversationID: UUID(), userMessageID: UUID())
        let viewModel = ConversationInputViewModel(capability: capability)

        viewModel.send()

        // 附件在进入异步编码前就离开挂起池；正文等提交成功再清空。
        #expect(capability.pendingFileAttachments.isEmpty)
        #expect(capability.text == "first")
        #expect(!viewModel.canSend)

        // 编码尚未完成时再次按回车：提交中标记挡住重复提交。
        viewModel.send()

        await waitUntil("附件消息未走后台提交") {
            !capability.backgroundCommits.isEmpty
        }
        #expect(capability.backgroundCommits.count == 1)
        #expect(capability.backgroundCommits.first?.fileAttachments.map(\.id) == [file.id])
    }

    @Test("附件提交失败时正文、折叠块与附件全部保留，可直接重试")
    func failedAttachmentCommitRestoresDraft() async {
        let capability = SendActionBarTestCapability()
        let file = UserFileAttachment(fileName: "notes.txt", mimeType: "text/plain", textContent: "notes")
        let block = CollapsedContentBlock(start: 0, length: 5, title: "first")
        capability.pendingFileAttachments = [file]
        capability.text = "first"
        capability.collapsedBlocks = [block]
        capability.commitError = SendActionBarTestError.failed
        let viewModel = ConversationInputViewModel(capability: capability)

        viewModel.send()

        // 编码窗口内正文就还在输入框里。
        #expect(viewModel.text == "first")
        #expect(capability.isCommittingDraft)

        await waitUntil("附件提交失败后错误未回填") {
            viewModel.errorMessage != nil
        }
        #expect(capability.text == "first")
        #expect(capability.collapsedBlocks == [block])
        #expect(capability.pendingFileAttachments.map(\.id) == [file.id])
        #expect(viewModel.fileAttachments.map(\.id) == [file.id])
        #expect(!capability.isCommittingDraft)
        #expect(viewModel.canSend)
    }

    @Test("附件提交成功后清空正文与折叠块")
    func successfulAttachmentCommitClearsDraft() async {
        let capability = SendActionBarTestCapability()
        let block = CollapsedContentBlock(start: 0, length: 5, title: "first")
        capability.pendingFileAttachments = [
            UserFileAttachment(fileName: "notes.txt", mimeType: "text/plain", textContent: "notes")
        ]
        capability.text = "first"
        capability.collapsedBlocks = [block]
        capability.commit = MessageSendCommit(conversationID: UUID(), userMessageID: UUID())
        let viewModel = ConversationInputViewModel(capability: capability)

        viewModel.send()

        await waitUntil("附件提交未结束") { !capability.isCommittingDraft }

        #expect(capability.text.isEmpty)
        #expect(capability.collapsedBlocks.isEmpty)
        #expect(viewModel.text.isEmpty)
    }

    @Test("编码期间继续输入时，成功提交不清空新草稿")
    func successfulAttachmentCommitKeepsEditedDraft() async {
        let capability = SendActionBarTestCapability()
        capability.pendingFileAttachments = [
            UserFileAttachment(fileName: "notes.txt", mimeType: "text/plain", textContent: "notes")
        ]
        capability.text = "first"
        capability.commit = MessageSendCommit(conversationID: UUID(), userMessageID: UUID())
        capability.holdsBackgroundCommits = true
        let viewModel = ConversationInputViewModel(capability: capability)

        viewModel.send()
        await waitUntil("后台提交未开始") { !capability.backgroundCommits.isEmpty }

        // 编码期间用户继续输入，这份新草稿不能被提交成功的清理抹掉。
        viewModel.setText("first edited")
        capability.releaseBackgroundCommits()
        await waitUntil("附件提交未结束") { !capability.isCommittingDraft }

        #expect(capability.text == "first edited")
        #expect(viewModel.text == "first edited")
    }

    // MARK: - 焦点 / 高度绑定

    @Test("焦点与高度绑定双向同步到能力层")
    func focusAndHeightBindingsWriteThrough() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        viewModel.setFocused(true)
        viewModel.setInputHeight(180)

        #expect(viewModel.isInputFocused)
        #expect(capability.isInputFocused)
        #expect(viewModel.inputHeight == 180)
        #expect(capability.inputHeight == 180)

        viewModel.setFocused(false)
        #expect(!viewModel.isInputFocused)
        #expect(!capability.isInputFocused)
    }
}

/// 1×1 PNG：必须能被 ImageIO 真正解码，附件才会进入待发送图片池。
let attachmentTestPNGBase64 = """
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==
"""
