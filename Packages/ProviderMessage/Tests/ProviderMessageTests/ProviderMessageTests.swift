import Foundation
import Testing
@testable import ProviderMessage

@Suite("ProviderMessage")
@MainActor
struct ProviderMessageTests {
    @Test("消息按创建时间返回并支持更新删除")
    func lifecycle() {
        let manager = DefaultMessageManager()
        let conversationID = UUID()
        let first = Message(conversationID: conversationID, role: .user, content: "hello")
        let second = Message(conversationID: conversationID, role: .assistant, content: "world")

        manager.insertMessage(first, to: conversationID)
        manager.insertMessage(second, to: conversationID)
        #expect(manager.messages(for: conversationID).map(\.id) == [first.id, second.id])
        manager.updateMessage(id: first.id, in: conversationID, content: "updated")
        #expect(manager.message(id: first.id, in: conversationID)?.content == "updated")
        manager.deleteMessage(id: second.id, in: conversationID)
        #expect(manager.messageCount(for: conversationID) == 1)
    }

    @Test("异步消息快照包含当前会话消息")
    func asyncSnapshot() async {
        let manager = DefaultMessageManager()
        let conversationID = UUID()
        let message = Message(conversationID: conversationID, role: .user, content: "snapshot")
        manager.insertMessage(message, to: conversationID)

        let snapshot = await manager.messagesSnapshot(in: conversationID)
        #expect(snapshot == [message])
        #expect(await manager.firstUserMessage(in: conversationID) == message)
    }

    @Test("消息与 token 可按自然日跨会话聚合")
    func dailyAggregates() async {
        let manager = DefaultMessageManager()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let firstConversation = UUID()
        let secondConversation = UUID()

        manager.insertMessage(
            Message(conversationID: firstConversation, role: .user, content: "one", createdAt: yesterday, inputTokenCount: 12),
            to: firstConversation
        )
        manager.insertMessage(
            Message(conversationID: secondConversation, role: .assistant, content: "two", createdAt: yesterday, outputTokenCount: 8),
            to: secondConversation
        )
        manager.insertMessage(
            Message(conversationID: firstConversation, role: .assistant, content: "three", createdAt: today, inputTokenCount: 3, outputTokenCount: 5),
            to: firstConversation
        )

        #expect(manager.dailyMessageCounts(since: yesterday) == [yesterday: 2, today: 1])
        #expect(manager.dailyTokenCounts(since: yesterday) == [yesterday: 20, today: 8])
        #expect(await manager.dailyMessageCountsAsync(since: yesterday) == [yesterday: 2, today: 1])
        #expect(await manager.dailyTokenCountsAsync(since: yesterday) == [yesterday: 20, today: 8])
    }

    @Test("消息插入观察者可接收事件并注销")
    func messageInsertionObservation() {
        let manager = DefaultMessageManager()
        let conversationID = UUID()
        var observed: [(UUID, UUID)] = []
        let handle = manager.addMessageInsertedObserver { message, conversation in
            observed.append((message.id, conversation))
        }
        let first = Message(conversationID: conversationID, role: .user, content: "first")
        manager.insertMessage(first, to: conversationID)
        handle.cancel()
        manager.insertMessage(Message(conversationID: conversationID, role: .assistant, content: "second"), to: conversationID)

        #expect(observed.count == 1)
        #expect(observed.first?.0 == first.id)
        #expect(observed.first?.1 == conversationID)
    }

    @Test("结构化消息变化观察者携带消息并支持注销")
    func messageChangeObservation() {
        let manager = DefaultMessageManager()
        let conversationID = UUID()
        var observed: [Message] = []
        let handle = manager.addMessageChangeObserver { change in
            guard case let .inserted(message, id) = change else { return }
            #expect(id == conversationID)
            observed.append(message)
        }

        let first = Message(conversationID: conversationID, role: .user, content: "first")
        manager.insertMessage(first, to: conversationID)
        handle.cancel()
        manager.insertMessage(
            Message(conversationID: conversationID, role: .assistant, content: "second"),
            to: conversationID
        )

        #expect(observed == [first])
    }

    @Test("本地文本文件转换为附件时不污染消息正文")
    func loadsTextFileAsAttachment() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-attachment-\(UUID().uuidString).txt")
        let data = Data("hello attachment".utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url)

        let attachment = try UserFileAttachmentLoader.load(from: url)

        #expect(attachment.fileName == url.lastPathComponent)
        #expect(attachment.mimeType == "text/plain")
        #expect(attachment.textContent == "hello attachment")
        #expect(Data(base64Encoded: attachment.base64Data ?? "") == data)
    }

    @Test("二进制文件保留字节并不伪装成文本")
    func loadsBinaryFileAsAttachment() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-attachment-\(UUID().uuidString).bin")
        let data = Data([0x00, 0xFF, 0x10, 0x80])
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url)

        let attachment = try UserFileAttachmentLoader.load(from: url)

        #expect(attachment.textContent == nil)
        #expect(Data(base64Encoded: attachment.base64Data ?? "") == data)
    }

    @Test("文本文件附件会渲染到发送给 LLM 的用户正文")
    func rendersTextFileAttachmentForLLM() {
        let content = UserAttachmentMetadata.appendingFileAttachments(
            [
                UserFileAttachment(
                    fileName: "ControlButtonsViewModel.swift",
                    mimeType: "text/x-swift",
                    textContent: "else { logger.error(\"failed\") }"
                ),
            ],
            to: "第64行，else区块内加上 error 日志"
        )

        #expect(content.contains("第64行，else区块内加上 error 日志"))
        #expect(content.contains("ControlButtonsViewModel.swift"))
        #expect(content.contains("else { logger.error(\"failed\") }"))
        #expect(content.contains("<attached_file"))
        #expect(content.contains("</attached_file>"))
    }

    @Test("二进制文件附件只渲染描述，不把 base64 混入提示词")
    func rendersBinaryFileDescriptionForLLM() {
        let content = UserAttachmentMetadata.appendingFileAttachments(
            [
                UserFileAttachment(
                    fileName: "archive.bin",
                    mimeType: "application/octet-stream",
                    base64Data: "AAEC"
                ),
            ],
            to: "请检查这个文件"
        )

        #expect(content.contains("archive.bin"))
        #expect(content.contains("application/octet-stream"))
        #expect(content.contains("content is not decoded"))
        #expect(!content.contains("AAEC"))
    }

    @Test("no attachments returns original content unchanged")
    func emptyAttachmentsReturnContent() {
        let content = "plain user text"
        #expect(UserAttachmentMetadata.appendingFileAttachments([], to: content) == content)
    }

    @Test("attachments to empty content render only the blocks")
    func attachmentsWithEmptyContent() {
        let content = UserAttachmentMetadata.appendingFileAttachments(
            [UserFileAttachment(fileName: "a.txt", mimeType: "text/plain", textContent: "AAA")],
            to: ""
        )
        #expect(content.hasPrefix("<attached_file"))
        #expect(content.contains("</attached_file>"))
        #expect(!content.contains("\n\n\n"))
    }

    @Test("special characters in names are attribute-escaped")
    func escapesAttributeCharacters() {
        let content = UserAttachmentMetadata.appendingFileAttachments(
            [UserFileAttachment(
                fileName: #"a<b>&"c".txt"#,
                mimeType: "text/plain",
                textContent: "x"
            )],
            to: ""
        )
        #expect(content.contains(#"name="a&lt;b&gt;&amp;&quot;c&quot;.txt""#))
    }

    @Test("multiple attachments are separated by a blank line")
    func multipleAttachmentsJoined() {
        let content = UserAttachmentMetadata.appendingFileAttachments(
            [
                UserFileAttachment(fileName: "1.txt", mimeType: "text/plain", textContent: "one"),
                UserFileAttachment(fileName: "2.txt", mimeType: "text/plain", textContent: "two"),
            ],
            to: ""
        )
        #expect(content.components(separatedBy: "</attached_file>").count == 3)
        #expect(content.contains("one"))
        #expect(content.contains("two"))
    }

    @Test("file attachment metadata round-trips through encode/decode")
    func fileAttachmentCodecRoundTrip() {
        let attachments = [
            UserFileAttachment(fileName: "n.md", mimeType: "text/markdown", textContent: "body"),
            UserFileAttachment(fileName: "p.bin", mimeType: "application/octet-stream", base64Data: "QQ=="),
        ]
        let metadata = UserAttachmentMetadata.encodeFileAttachments(attachments)
        let decoded = UserAttachmentMetadata.decodeFileAttachments(from: metadata)
        #expect(decoded == attachments)

        #expect(UserAttachmentMetadata.decodeFileAttachments(from: [:]).isEmpty)
        #expect(UserAttachmentMetadata.decodeFileAttachments(from: ["bad": "{!!"]).isEmpty)
    }

    @Test("image attachment metadata round-trips")
    func imageAttachmentCodecRoundTrip() {
        let images = [
            UserImageAttachment(mimeType: "image/png", base64Data: "QQ==", fileName: "a.png"),
        ]
        let metadata = UserAttachmentMetadata.encodeImageAttachments(images)
        let decoded = UserAttachmentMetadata.decodeImageAttachments(from: metadata)
        #expect(decoded == images)
    }

    @Test("extract reads the latest user message carrying file attachments")
    func extractLatestUserFileAttachments() {
        let conv = UUID()
        let older = Message(
            conversationID: conv, role: .user, content: "old",
            metadata: [UserAttachmentMetadata.fileAttachmentsKey: "[]"]
        )
        let files = [UserFileAttachment(fileName: "x.txt", mimeType: "text/plain", textContent: "x")]
        let recentMetadata = UserAttachmentMetadata.encodeFileAttachments(files)
        let recent = Message(
            conversationID: conv, role: .user, content: "new", metadata: recentMetadata
        )
        let assistant = Message(conversationID: conv, role: .assistant, content: "reply")

        #expect(UserAttachmentMetadata.extractFileAttachments(from: [older, assistant, recent]) == files)
        #expect(UserAttachmentMetadata.extractFileAttachments(from: [assistant]).isEmpty)
        // older message carries the key but decodes to an empty list.
        #expect(UserAttachmentMetadata.extractFileAttachments(from: [older]).isEmpty)
    }

    @Test("isContextCompaction matches renderKind or metadata marker")
    func isContextCompactionDetection() {
        let conv = UUID()
        let byRenderKind = Message(
            conversationID: conv, role: .system, content: "", renderKind: "context-compaction"
        )
        let byMetadata = Message(
            conversationID: conv, role: .system, content: "",
            metadata: ["lumi.timelineEvent": "context-compaction"]
        )
        let plain = Message(conversationID: conv, role: .user, content: "hi")

        #expect(MessageTimelineEvent.isContextCompaction(byRenderKind))
        #expect(MessageTimelineEvent.isContextCompaction(byMetadata))
        #expect(!MessageTimelineEvent.isContextCompaction(plain))
    }

    @Test("isActualContextCompaction requires the actual marker")
    func actualCompactionRequiresMarker() {
        let conv = UUID()
        let legacyMarker = Message(
            conversationID: conv, role: .system, content: "",
            metadata: ["lumi.timelineEvent": "context-compaction"]
        )
        let actual = Message(
            conversationID: conv, role: .system, content: "",
            metadata: [
                "lumi.timelineEvent": "context-compaction",
                "contextCompactionActual": "true",
            ]
        )

        #expect(!MessageTimelineEvent.isActualContextCompaction(legacyMarker))
        #expect(MessageTimelineEvent.isActualContextCompaction(actual))
    }

    @Test("compactionReason maps known values and falls back to legacy")
    func compactionReasonMapping() {
        let conv = UUID()
        func msg(_ raw: String?) -> Message {
            Message(
                conversationID: conv, role: .system, content: "",
                metadata: raw.map { ["contextCompactionReason": $0] } ?? [:]
            )
        }

        #expect(MessageTimelineEvent.compactionReason(for: msg("hard-threshold")) == .hardThreshold)
        #expect(MessageTimelineEvent.compactionReason(for: msg("emergency")) == .emergency)
        #expect(MessageTimelineEvent.compactionReason(for: msg("context-limit-retry")) == .contextLimitRetry)
        #expect(MessageTimelineEvent.compactionReason(for: msg("unknown")) == .legacy)
        #expect(MessageTimelineEvent.compactionReason(for: msg(nil)) == .legacy)
    }

    @Test("integerMetadata parses int strings and tolerates missing or non-numeric")
    func integerMetadataParsing() {
        let conv = UUID()
        let numeric = Message(
            conversationID: conv, role: .system, content: "",
            metadata: ["k": "123"]
        )
        let nonNumeric = Message(
            conversationID: conv, role: .system, content: "",
            metadata: ["k": "abc"]
        )
        let missing = Message(conversationID: conv, role: .system, content: "")

        #expect(MessageTimelineEvent.integerMetadata("k", from: numeric) == 123)
        #expect(MessageTimelineEvent.integerMetadata("k", from: nonNumeric) == nil)
        #expect(MessageTimelineEvent.integerMetadata("k", from: missing) == nil)
    }
}
