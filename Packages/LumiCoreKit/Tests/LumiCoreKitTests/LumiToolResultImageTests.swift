import Foundation
import LumiCoreKit
import Testing

struct LumiToolResultImageTests {
    @Test func defaultImageAttachmentsIsEmpty() {
        let result = LumiToolResult(content: "done")
        #expect(result.imageAttachments.isEmpty)
    }

    @Test func roundTripsWithImages() throws {
        let image = LumiImageAttachment(
            mimeType: "image/png",
            base64Data: Data([0x89, 0x50, 0x4E, 0x47]).base64EncodedString(),
            fileName: "shot.png"
        )
        let original = LumiToolResult(content: "ok", duration: 0.5, isError: false, imageAttachments: [image])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LumiToolResult.self, from: data)

        #expect(decoded.content == "ok")
        #expect(decoded.duration == 0.5)
        #expect(decoded.isError == false)
        #expect(decoded.imageAttachments.count == 1)
        #expect(decoded.imageAttachments.first?.mimeType == "image/png")
        #expect(decoded.imageAttachments.first?.fileName == "shot.png")
    }

    @Test func decodesLegacyJSONWithoutImageField() throws {
        // 旧版本持久化的 LumiToolResult 不含 imageAttachments 字段，解码时必须回退为空数组。
        let legacyJSON = """
        {"content":"plain","isError":false}
        """
        let data = try #require(legacyJSON.data(using: .utf8))

        let decoded = try JSONDecoder().decode(LumiToolResult.self, from: data)
        #expect(decoded.content == "plain")
        #expect(decoded.imageAttachments.isEmpty)
        #expect(decoded.isError == false)
    }
}

struct LumiToolExecutionContextImageTests {
    @Test func collectReturnsAttachedImages() {
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "tc1",
            toolName: "read_file"
        )

        #expect(context.collectImages().isEmpty)

        let image = LumiImageAttachment(mimeType: "image/png", base64Data: "AAAA")
        context.attachImage(image)

        let collected = context.collectImages()
        #expect(collected.count == 1)
        #expect(collected.first?.mimeType == "image/png")

        // collectImages 清空容器，二次调用为空
        #expect(context.collectImages().isEmpty)
    }

    @Test func attachImagesAppendsMultiple() {
        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "tc1",
            toolName: "read_file"
        )

        context.attachImages([
            LumiImageAttachment(mimeType: "image/png", base64Data: "AAAA"),
            LumiImageAttachment(mimeType: "image/jpeg", base64Data: "BBBB")
        ])
        context.attachImage(LumiImageAttachment(mimeType: "image/gif", base64Data: "CCCC"))

        let collected = context.collectImages()
        #expect(collected.count == 3)
        #expect(collected.map(\.mimeType) == ["image/png", "image/jpeg", "image/gif"])
    }
}
