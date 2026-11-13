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

    @Test("仅 structuredContent 序列化为 JSON 文本（**#180**）")
    func structuredContentOnly() {
        let result = MCPContentCodec.encode(
            [],
            structuredContent: .object(["answer": .int(42)]),
            isError: false
        )
        #expect(result.text == "{\"answer\":42}")
        #expect(result.images.isEmpty)
        #expect(result.isError == false)
    }

    @Test("content 与 structuredContent 同时保留（**#180**）")
    func contentAndStructuredContent() {
        let content: [Tool.Content] = [.text(text: "hello", annotations: nil, _meta: nil)]
        let result = MCPContentCodec.encode(
            content,
            structuredContent: .object(["answer": .int(42)]),
            isError: false
        )
        #expect(result.text == "hello\n{\"answer\":42}")
    }

    @Test("嵌套 structuredContent 仍是合法 JSON 且内容保真（**#180**）")
    func nestedStructuredContentIsValidJSON() throws {
        let structured: Value = .object([
            "items": .array([.int(1), .int(2)]),
            "meta": .object(["ok": .bool(true)]),
        ])
        let result = MCPContentCodec.encode([], structuredContent: structured, isError: false)
        let data = try #require(result.text.data(using: .utf8))
        let parsed = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(parsed["items"] as? [Int] == [1, 2])
        #expect((parsed["meta"] as? [String: Any])?["ok"] as? Bool == true)
    }

    @Test("structuredContent 为 nil 时文本编码不变（**#180**）")
    func structuredContentNilPreservesText() {
        let content: [Tool.Content] = [.text(text: "hi", annotations: nil, _meta: nil)]
        let result = MCPContentCodec.encode(content, structuredContent: nil, isError: false)
        #expect(result.text == "hi")
    }
}
