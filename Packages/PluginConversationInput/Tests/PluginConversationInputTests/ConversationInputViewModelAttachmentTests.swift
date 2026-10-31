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

    @Test("拖入目录时路径按需换行插入并聚焦输入框")
    func droppingDirectoryInsertsPathIntoText() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        // 空输入框 → 直接写入，不加前导换行。
        viewModel.insertDirectoryPath(URL(fileURLWithPath: "/tmp/pkg"))
        #expect(viewModel.text == "/tmp/pkg")

        // 已有内容且不以换行结尾 → 追加换行再写路径，避免与已有文字黏在一起。
        viewModel.insertDirectoryPath(URL(fileURLWithPath: "/tmp/other"))
        #expect(viewModel.text == "/tmp/pkg\n/tmp/other")

        // 拖放会强制聚焦，用户可以直接继续写指令。
        #expect(capability.isInputFocused)
    }

    @Test("已有内容以换行结尾时目录路径直接追加不重复换行")
    func droppingDirectoryAfterTrailingNewlineDoesNotDouble() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        capability.text = "look at\n"
        viewModel.refresh()

        viewModel.insertDirectoryPath(URL(fileURLWithPath: "/tmp/pkg"))

        #expect(viewModel.text == "look at\n/tmp/pkg")
    }

    // MARK: - 拖放：图片 / 文件 → 挂起池

    @Test("拖入图片进入图片池并聚焦输入框")
    func droppingImageAttachesToImagePool() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("conversation-input-image-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("pixel.png")
        #expect(FileManager.default.createFile(atPath: fileURL.path, contents: Data([0x89, 0x50])))

        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        viewModel.attachImage(fileURL)

        await waitUntil("图片附件未加入挂起池") {
            !capability.pendingImageAttachments.isEmpty
        }

        let attachment = try #require(capability.pendingImageAttachments.first)
        #expect(attachment.fileName == "pixel.png")
        // 扩展名决定 MIME，未知扩展名回落到 image/png。
        #expect(attachment.mimeType == "image/png")
        #expect(attachment.base64Data == Data([0x89, 0x50]).base64EncodedString())
        #expect(capability.isInputFocused)
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
