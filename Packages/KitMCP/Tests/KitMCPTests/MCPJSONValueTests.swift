import Foundation
import MCP
import Testing
@testable import KitMCP

@Suite("MCPJSONValue")
struct MCPJSONValueTests {
    @Test("MCP Value 往返转换")
    func valueRoundTrip() {
        let object: Value = .object([
            "type": .string("object"),
            "required": .array([.string("name")]),
            "count": .int(3),
            "ratio": .double(0.5),
            "flag": .bool(true),
            "nested": .object(["ok": .null]),
        ])

        let converted = MCPJSONValue(from: object)
        let back = converted.mcpValue()

        #expect(back == object)
    }

    @Test("foundationValue 产生 JSON 兼容对象")
    func foundationValue() {
        let value: MCPJSONValue = .object([
            "text": .string("hello"),
            "items": .array([.int(1), .int(2)]),
            "empty": .null,
        ])

        let any = value.foundationValue()
        #expect(JSONSerialization.isValidJSONObject(any))
        guard let object = any as? [String: Any] else {
            Issue.record("expected object")
            return
        }
        #expect(object["text"] as? String == "hello")
        #expect((object["items"] as? [Any])?.count == 2)
    }

    @Test("fromFoundation 含不支持的值时整体返回 nil（不静默丢参数）")
    func fromFoundation() {
        let source: [String: Any] = [
            "string": "x",
            "int": 42,
            "unsupported": Data([0x00]),
        ]

        // 字典里出现无法 JSON 化的值 → 整体失败，避免调用时静默丢参数。
        #expect(MCPJSONValue.fromFoundation(source) == nil)

        let clean: [String: Any] = [
            "string": "x",
            "int": 42,
            "array": [1, "two", false],
            "nested": ["a": 1.5],
        ]
        guard case .object(let object) = MCPJSONValue.fromFoundation(clean) else {
            Issue.record("expected object")
            return
        }
        #expect(Set(object.keys) == Set(["string", "int", "array", "nested"]))
    }

    @Test("jsonString 输出规范 JSON")
    func jsonString() throws {
        let value: MCPJSONValue = .object([
            "type": .string("object"),
            "properties": .object(["name": .object(["type": .string("string")])]),
        ])

        let json = try #require(value.jsonString())
        let data = try #require(json.data(using: .utf8))
        let decoded = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(decoded["type"] as? String == "object")
    }

    @Test("MCPValueCoding 把上层参数字典转为 MCP Value")
    func mcpArguments() {
        let source: [String: Any] = [
            "scheme": "Debug",
            "quiet": true,
            "targets": ["Lumi", "Tests"],
        ]

        let args = MCPValueCoding.mcpArguments(from: source)
        #expect(args["scheme"]?.stringValue == "Debug")
        #expect(args["quiet"]?.boolValue == true)
        #expect(args["targets"]?.arrayValue?.count == 2)
    }
}
