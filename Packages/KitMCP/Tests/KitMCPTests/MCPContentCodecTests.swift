import Foundation
import MCP
import Testing
@testable import KitMCP

@Suite("MCPContentCodec")
struct MCPContentCodecTests {
    @Test("文本与图片混合编码")
    func textAndImage() {
        let content: [Tool.Content] = [
            .text(text: "line 1", annotations: nil, _meta: nil),
            .text(text: "line 2", annotations: nil, _meta: nil),
            .image(data: "aGVsbG8=", mimeType: "image/png", annotations: nil, _meta: nil),
        ]

        let result = MCPContentCodec.encode(content, isError: false)
        #expect(result.text == "line 1\nline 2")
        #expect(result.images.count == 1)
        #expect(result.images.first?.base64Data == "aGVsbG8=")
        #expect(result.images.first?.mimeType == "image/png")
        #expect(result.isError == false)
    }

    @Test("resourceLink 以文本标记呈现")
    func resourceLink() {
        let content: [Tool.Content] = [
            .resourceLink(uri: "file:///tmp/a.swift", name: "a.swift", title: nil, description: nil, mimeType: nil, annotations: nil),
        ]

        let result = MCPContentCodec.encode(content, isError: false)
        #expect(result.text.contains("file:///tmp/a.swift"))
        #expect(result.images.isEmpty)
    }

    @Test("isError 透传")
    func errorFlag() {
        let content: [Tool.Content] = [.text(text: "boom", annotations: nil, _meta: nil)]
        let result = MCPContentCodec.encode(content, isError: true)
        #expect(result.isError == true)
    }
}
