import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageManager

/// 回归：LLM 窄读取必须保留附件 metadata。
///
/// 发送侧把图片/文件附件写进 `Message.metadata`，请求侧
/// `Message.llmMessage` 从 metadata 解码并注入 LLM 请求。
/// 窄读取曾只还原时间线标记，附件在请求路径上被整体丢弃：
/// UI 显示附件 chip，模型却回答「看不到文件」。
@MainActor
@Suite("LLM 窄读取保留附件 metadata")
struct LLMContextAttachmentMetadataTests {

    @Test("窄读取还原图片/文件附件，仍跳过无关 metadata")
    func llmReadKeepsAttachmentMetadata() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LLMAttach-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try MessageStore(databaseRootURL: directory)

        let conversationID = UUID()
        let file = UserFileAttachment(
            fileName: "sn_list.txt",
            mimeType: "text/plain",
            base64Data: Data("SN001\nSN002".utf8).base64EncodedString(),
            textContent: "SN001\nSN002",
            localPath: "/tmp/sn_list.txt"
        )
        let image = UserImageAttachment(
            mimeType: "image/png",
            base64Data: Data([0x89, 0x50, 0x4E, 0x47]).base64EncodedString()
        )
        var metadata = UserAttachmentMetadata.encodeFileAttachments([file])
        metadata.merge(UserAttachmentMetadata.encodeImageAttachments([image])) { _, new in new }
        metadata["unrelated"] = "不应被物化"

        let userMessage = Message(
            conversationID: conversationID,
            role: .user,
            content: "这个txt就是列表",
            metadata: metadata
        )
        try store.insertMessage(userMessage)

        let manager = MessageManager(store: store, dataDirectory: directory)
        let llm = await manager.messagesForLLM(in: conversationID)
        let read = try #require(llm.first { $0.id == userMessage.id })

        #expect(UserAttachmentMetadata.decodeFileAttachments(from: read.metadata) == [file])
        #expect(UserAttachmentMetadata.decodeImageAttachments(from: read.metadata) == [image])
        #expect(read.metadata["unrelated"] == nil, "无关 metadata 仍不应被物化")
        #expect(read.rawStreamEventsJSON == nil)

        // 注入入口必须能从窄读取结果里拿回文件正文。
        let injected = UserAttachmentMetadata.appendingFileAttachments(
            UserAttachmentMetadata.decodeFileAttachments(from: read.metadata),
            to: read.content
        )
        #expect(injected.contains("SN001"))
        #expect(injected.contains("sn_list.txt"))
    }
}