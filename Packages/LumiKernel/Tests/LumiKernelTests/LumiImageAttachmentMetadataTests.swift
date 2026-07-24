import Foundation
import Testing
@testable import LumiKernel

@Suite("LumiImageAttachmentMetadata")
@MainActor
struct LumiImageAttachmentMetadataTests {

    // MARK: - encode

    @Test("encode: 空数组返回原 base,不写入 key")
    func encodeEmptyReturnsBase() {
        let base: [String: String] = ["existing": "value"]
        let result = LumiImageAttachmentMetadata.encode([], into: base)
        #expect(result == base)
        #expect(result["imageAttachments"] == nil)
    }

    @Test("encode: 非空数组写入合法 JSON 字符串")
    func encodeWritesJSONString() throws {
        let attachment = LumiImageAttachment(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            mimeType: "image/png",
            base64Data: "aGVsbG8=",
            fileName: "shot.png"
        )
        let result = LumiImageAttachmentMetadata.encode([attachment])

        let json = try #require(result[LumiImageAttachmentMetadata.key])
        let decoded = try JSONDecoder().decode([LumiImageAttachment].self, from: Data(json.utf8))
        #expect(decoded.count == 1)
        #expect(decoded[0].id == attachment.id)
        #expect(decoded[0].mimeType == "image/png")
        #expect(decoded[0].base64Data == "aGVsbG8=")
        #expect(decoded[0].fileName == "shot.png")
    }

    @Test("encode: 不覆盖 base 中已存在的 key")
    func encodePreservesBaseKeys() {
        let attachment = LumiImageAttachment(
            mimeType: "image/jpeg",
            base64Data: "xxxx"
        )
        let base: [String: String] = ["renderKind": "tool", "trace": "abc"]
        let result = LumiImageAttachmentMetadata.encode([attachment], into: base)
        #expect(result["renderKind"] == "tool")
        #expect(result["trace"] == "abc")
        #expect(result[LumiImageAttachmentMetadata.key] != nil)
    }

    // MARK: - extract

    @Test("extract: 历史为空时返回空数组")
    func extractFromEmptyHistory() {
        let result = LumiImageAttachmentMetadata.extract(from: [])
        #expect(result.isEmpty)
    }

    @Test("extract: 历史里没有 user 消息时返回空数组")
    func extractWithoutUserMessage() {
        let assistant = LumiChatMessage(
            conversationID: UUID(),
            role: .assistant,
            content: "hi"
        )
        let result = LumiImageAttachmentMetadata.extract(from: [assistant])
        #expect(result.isEmpty)
    }

    @Test("extract: user message 没有 metadata 时返回空数组")
    func extractWithoutMetadata() {
        let user = LumiChatMessage(
            conversationID: UUID(),
            role: .user,
            content: "hi"
        )
        let result = LumiImageAttachmentMetadata.extract(from: [user])
        #expect(result.isEmpty)
    }

    @Test("extract: user message metadata 是非法 JSON 时返回空数组")
    func extractFromCorruptJSON() {
        let user = LumiChatMessage(
            conversationID: UUID(),
            role: .user,
            content: "hi",
            metadata: [LumiImageAttachmentMetadata.key: "{not json"]
        )
        let result = LumiImageAttachmentMetadata.extract(from: [user])
        #expect(result.isEmpty)
    }

    @Test("extract: 多轮历史下取最近一条 user 的 attachments")
    func extractPicksLastUser() throws {
        let id1 = UUID()
        let id2 = UUID()

        let oldUser = LumiChatMessage(
            conversationID: UUID(),
            role: .user,
            content: "first",
            metadata: LumiImageAttachmentMetadata.encode([
                LumiImageAttachment(id: id1, mimeType: "image/png", base64Data: "old")
            ])
        )
        let assistant = LumiChatMessage(
            conversationID: UUID(),
            role: .assistant,
            content: "ack"
        )
        let latestUser = LumiChatMessage(
            conversationID: UUID(),
            role: .user,
            content: "second",
            metadata: LumiImageAttachmentMetadata.encode([
                LumiImageAttachment(id: id2, mimeType: "image/jpeg", base64Data: "new")
            ])
        )

        let result = LumiImageAttachmentMetadata.extract(from: [oldUser, assistant, latestUser])
        #expect(result.count == 1)
        #expect(result[0].id == id2)
        #expect(result[0].base64Data == "new")
    }
}