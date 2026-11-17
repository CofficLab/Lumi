import Foundation
import KernelCore
import ProviderAgentLoop
import ProviderMessage
import ProviderMessageSender
import Testing
@testable import PluginMessageRenderer

/// 回归 #372：重发携带附件的历史用户消息时，附件必须随正文一起送出。
///
/// 旧实现的重发链路只把 `message.content` 交给发送器，落库进 metadata 的
/// 图片与文件附件在重发后全部丢失，模型收到的新消息与首次发送不等价。
/// 修复后 capability 从消息 metadata 还原原始附件并走显式附件重载。
@Suite("重发消息保留原始附件（#372）")
@MainActor
struct ResendMessageAttachmentsTests {

    /// 记录显式附件重载调用、并对便捷重载计数的发送器替身。
    private final class MessageSendingProvidingStub: MessageSendingProviding {

        struct SentMessage: Equatable {
            let content: String
            let imageAttachments: [UserImageAttachment]
            let fileAttachments: [UserFileAttachment]
            let conversationID: UUID?
        }

        private(set) var legacyCalls = 0
        private(set) var sentMessages: [SentMessage] = []

        func sendMessage(_ content: String, conversationID: UUID?) async throws {
            legacyCalls += 1
        }

        func sendMessage(
            _ content: String,
            imageAttachments: [UserImageAttachment],
            fileAttachments: [UserFileAttachment],
            conversationID: UUID?
        ) async throws {
            sentMessages.append(
                SentMessage(
                    content: content,
                    imageAttachments: imageAttachments,
                    fileAttachments: fileAttachments,
                    conversationID: conversationID
                )
            )
        }

        // MARK: 未使用的协议成员

        var isSending: Bool { false }

        var pendingImageAttachments: [UserImageAttachment] { [] }
        var pendingFileAttachments: [UserFileAttachment] { [] }

        func addImageAttachment(_ attachment: UserImageAttachment) {}
        func removeImageAttachment(id: UUID) {}
        func clearImageAttachments() {}
        func addFileAttachment(_ attachment: UserFileAttachment) {}
        func removeFileAttachment(id: UUID) {}
        func clearFileAttachments() {}

        func addSendingStateObserver(_ callback: @escaping (Bool) -> Void) -> any SendingStateObserverHandle {
            NoopSendingStateHandle()
        }

        func pendingMessages(for conversationID: UUID) -> [PendingChatMessage] { [] }

        func cancelPendingMessage(id: UUID, in conversationID: UUID) {}

        func commitUserMessage(_ content: String, conversationID: UUID?) throws -> MessageSendCommit? {
            fatalError("unused")
        }

        func commitUserMessage(
            _ content: String,
            imageAttachments: [UserImageAttachment],
            fileAttachments: [UserFileAttachment],
            conversationID: UUID?
        ) throws -> MessageSendCommit? {
            fatalError("unused")
        }

        func commitUserMessageInBackground(
            _ content: String,
            imageAttachments: [UserImageAttachment],
            fileAttachments: [UserFileAttachment],
            conversationID: UUID?
        ) async throws -> MessageSendCommit? {
            fatalError("unused")
        }

        func startTurn(for commit: MessageSendCommit) async {}

        func cancelCurrentRequest() {}

        func resumeTurn(
            in conversationID: UUID,
            request: AgentTurnResumeRequest
        ) async throws -> AgentLoopOutcome {
            fatalError("unused")
        }
    }

    private final class NoopSendingStateHandle: SendingStateObserverHandle {
        func cancel() {}
    }

    private func makeAdapter(sender: MessageSendingProvidingStub) -> MessageRendererCapabilityAdapter {
        let kernel = KernelCoreContainer()
        try? kernel.registerProvider((any MessageSendingProviding).self, sender)
        return MessageRendererCapabilityAdapter(kernel: kernel)
    }

    private func makeMessage(
        images: [UserImageAttachment],
        files: [UserFileAttachment],
        conversationID: UUID
    ) -> Message {
        var message = Message(
            conversationID: conversationID,
            role: .user,
            content: "看看这两张图和这份文件"
        )
        message.metadata = UserAttachmentMetadata.encodeImageAttachments(images)
            .merging(UserAttachmentMetadata.encodeFileAttachments(files)) { current, _ in current }
        return message
    }

    @Test("重发携带图片与文件附件的消息时附件被完整还原")
    func resendRestoresOriginalAttachments() async throws {
        let images = [
            UserImageAttachment(mimeType: "image/png", base64Data: "aW1hZ2Ux", fileName: "shot1.png"),
            UserImageAttachment(mimeType: "image/jpeg", base64Data: "aW1hZ2Uy", fileName: nil),
        ]
        let files = [
            UserFileAttachment(fileName: "notes.txt", mimeType: "text/plain", textContent: "正文"),
            UserFileAttachment(
                fileName: "dump.bin",
                mimeType: "application/octet-stream",
                base64Data: "YmluYXJ5",
                localPath: "/tmp/dump.bin"
            ),
        ]
        let conversationID = UUID()
        let message = makeMessage(images: images, files: files, conversationID: conversationID)
        let sender = MessageSendingProvidingStub()
        let adapter = makeAdapter(sender: sender)

        await adapter.resendMessage(message)

        #expect(sender.legacyCalls == 0)
        #expect(sender.sentMessages.count == 1)
        let sent = try #require(sender.sentMessages.first)
        #expect(sent.content == message.content)
        #expect(sent.conversationID == conversationID)
        #expect(sent.imageAttachments == images)
        #expect(sent.fileAttachments == files)
    }

    @Test("重发纯文字消息时附件为空且不消耗挂起池")
    func resendOfTextOnlyMessageSendsEmptyAttachments() async throws {
        let conversationID = UUID()
        let message = Message(
            conversationID: conversationID,
            role: .user,
            content: "只有文字"
        )
        let sender = MessageSendingProvidingStub()
        let adapter = makeAdapter(sender: sender)

        await adapter.resendMessage(message)

        #expect(sender.legacyCalls == 0)
        let sent = try #require(sender.sentMessages.first)
        #expect(sent.content == message.content)
        #expect(sent.imageAttachments.isEmpty)
        #expect(sent.fileAttachments.isEmpty)
    }
}
