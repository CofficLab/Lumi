import Foundation
import ProviderMessage
import ProviderMessageSender
import Testing
@testable import PluginConversationInput

/// 附件异步读取与发送之间的竞态（#1023）。
///
/// 用户选择附件后，`attachImage` / `attachFile` 在后台读取文件，附件要等读取
/// 结束才进入挂起池。发送入口如果在读取窗口内快照，就会漏掉刚选中的附件，
/// 附件又会滚进下一条无关消息。这里覆盖两条发送入口的等待行为。
@MainActor
@Suite("附件读取期间的发送门禁")
struct AttachmentReadSendGateTests {
    @Test("输入框发送等待在途附件读取，读完的附件随本条消息发出")
    func conversationInputWaitsForAttachmentRead() async throws {
        let capability = SendActionBarTestCapability()
        capability.text = "analyze this"
        let viewModel = ConversationInputViewModel(capability: capability)

        // 模拟「已选中附件、还在读取」的窗口。
        capability.beginAttachmentRead()
        viewModel.send()

        await awaitSettle()
        #expect(capability.commits.isEmpty)
        #expect(capability.backgroundCommits.isEmpty)

        let attachment = UserFileAttachment(
            fileName: "notes.txt",
            mimeType: "text/plain",
            textContent: "hello"
        )
        capability.pendingFileAttachments = [attachment]
        capability.endAttachmentRead()

        await waitUntil("附件读取结束后未发出消息") {
            !capability.backgroundCommits.isEmpty
        }
        let commit = try #require(capability.backgroundCommits.first)
        #expect(commit.content == "analyze this")
        #expect(commit.fileAttachments.map(\.id) == [attachment.id])
    }

    @Test("发送按钮同样等待在途附件读取")
    func sendActionBarWaitsForAttachmentRead() async throws {
        let capability = SendActionBarTestCapability()
        capability.text = "ship it"
        let viewModel = SendActionBarViewModel(capability: capability)

        capability.beginAttachmentRead()
        viewModel.send()

        await awaitSettle()
        #expect(capability.backgroundCommits.isEmpty)

        let attachment = UserFileAttachment(
            fileName: "report.pdf",
            mimeType: "application/pdf",
            base64Data: "JVBERi0="
        )
        capability.pendingFileAttachments = [attachment]
        capability.endAttachmentRead()

        await waitUntil("附件读取结束后未发出消息") {
            !capability.backgroundCommits.isEmpty
        }
        let commit = try #require(capability.backgroundCommits.first)
        #expect(commit.content == "ship it")
        #expect(commit.fileAttachments.map(\.id) == [attachment.id])
    }

    @Test("等待期间重复触发发送不会排队第二条发送链")
    func repeatedSendWhileWaitingCommitsOnce() async throws {
        let capability = SendActionBarTestCapability()
        capability.text = "once"
        let viewModel = ConversationInputViewModel(capability: capability)

        capability.beginAttachmentRead()
        viewModel.send()
        viewModel.send()
        viewModel.send()

        await awaitSettle()
        #expect(capability.commits.isEmpty)

        capability.endAttachmentRead()

        await waitUntil("等待结束后未发出消息") {
            capability.commits.count == 1
        }
        await awaitSettle()
        #expect(capability.commits.count == 1)
        #expect(capability.backgroundCommits.isEmpty)
    }

    @Test("附件读取在挂起池入池前同步登记，读完归零")
    func attachFileRegistersReadSynchronously() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("attachment-read-gate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("readme.txt")
        #expect(
            FileManager.default.createFile(
                atPath: fileURL.path,
                contents: Data("hello".utf8)
            )
        )

        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        viewModel.attachFile(fileURL)
        // 登记发生在启动读取之前，调用返回时就已在途。
        #expect(capability.pendingAttachmentReadCount == 1)

        await waitUntil("附件读取未结束", timeout: .seconds(10)) {
            !capability.pendingFileAttachments.isEmpty
        }
        #expect(capability.pendingAttachmentReadCount == 0)
    }
}
