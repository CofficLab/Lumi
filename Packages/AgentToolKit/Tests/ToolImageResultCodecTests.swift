import Foundation
import Testing
@testable import AgentToolKit

struct ToolImageResultCodecTests {
    @Test
    func encodePrefixesMarkerAndRoundTripsContent() throws {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        let attachment = ImageAttachment(data: imageData, mimeType: "image/png")
        let encoded = ToolImageResultCodec.encode(content: "Screenshot captured", images: [attachment])

        #expect(encoded.hasPrefix("__LUMI_TOOL_IMAGE_RESULT__:"))

        let decoded = try #require(ToolImageResultCodec.decode(encoded))
        #expect(decoded.content == "Screenshot captured")
        #expect(decoded.images.count == 1)
        #expect(decoded.images[0].data == imageData)
        #expect(decoded.images[0].mimeType == "image/png")
    }

    @Test
    func decodeReturnsNilForPlainTextResult() {
        #expect(ToolImageResultCodec.decode("plain tool output") == nil)
    }

    @Test
    func decodeReturnsNilForInvalidJSONPayload() {
        let invalid = "__LUMI_TOOL_IMAGE_RESULT__:{not-json"
        #expect(ToolImageResultCodec.decode(invalid) == nil)
    }

    @Test
    func decodeSkipsImagesWithInvalidBase64() throws {
        let json = """
        {
            "content": "mixed",
            "images": [
                {"dataBase64": "not-valid-base64!!!", "mimeType": "image/png"},
                {"dataBase64": "\(Data([0x01]).base64EncodedString())", "mimeType": "image/jpeg"}
            ]
        }
        """
        let payload = "__LUMI_TOOL_IMAGE_RESULT__:" + json
        let decoded = try #require(ToolImageResultCodec.decode(payload))

        #expect(decoded.content == "mixed")
        #expect(decoded.images.count == 1)
        #expect(decoded.images[0].mimeType == "image/jpeg")
    }

    @Test
    func encodeHandlesMultipleImages() throws {
        let first = ImageAttachment(data: Data([0x01]), mimeType: "image/png")
        let second = ImageAttachment(data: Data([0x02]), mimeType: "image/jpeg")
        let encoded = ToolImageResultCodec.encode(content: "two images", images: [first, second])
        let decoded = try #require(ToolImageResultCodec.decode(encoded))

        #expect(decoded.images.count == 2)
        #expect(decoded.images.map(\.mimeType) == ["image/png", "image/jpeg"])
    }

    @Test
    func encodeWithEmptyImagesStillRoundTripsContent() throws {
        let encoded = ToolImageResultCodec.encode(content: "text only", images: [])
        let decoded = try #require(ToolImageResultCodec.decode(encoded))

        #expect(decoded.content == "text only")
        #expect(decoded.images.isEmpty)
    }

    @Test
    func encodePreservesUnicodeContent() throws {
        let encoded = ToolImageResultCodec.encode(content: "截图 🎉 中文", images: [])
        let decoded = try #require(ToolImageResultCodec.decode(encoded))

        #expect(decoded.content == "截图 🎉 中文")
    }
}
