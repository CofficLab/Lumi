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

    @Test("JSON 数字 0/1 不得被误判为布尔（回归 #1154）")
    func jsonZeroAndOneStayNumbers() throws {
        // 必须走 JSONSerialization：数字叶子是 NSNumber，
        // 原生 Swift Int 字面量不会触发 0/1 → Bool 的桥接误判。
        let data = try #require(
            #"{"count":0,"flag":1,"two":2,"on":true,"off":false,"nested":{"items":[0,1,true],"ratio":0.5}}"#
                .data(using: .utf8)
        )
        let source = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        guard case .object(let object) = MCPJSONValue.fromFoundation(source) else {
            Issue.record("expected object")
            return
        }
        #expect(object["count"] == .int(0))
        #expect(object["flag"] == .int(1))
        #expect(object["two"] == .int(2))
        #expect(object["on"] == .bool(true))
        #expect(object["off"] == .bool(false))
        #expect(
            object["nested"] == .object([
                "items": .array([.int(0), .int(1), .bool(true)]),
                "ratio": .double(0.5),
            ])
        )
    }

    @Test("MCP 调用参数中的 JSON 0/1 以数字送达（回归 #1154）")
    func mcpArgumentsPreserveJSONZeroAndOne() throws {
        let data = try #require(#"{"count":0,"mode":1}"#.data(using: .utf8))
        let source = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        let args = MCPValueCoding.mcpArguments(from: source)
        #expect(args["count"] == .int(0))
        #expect(args["mode"] == .int(1))
    }

    @Test("原生 Swift 布尔与数字的桥接行为不变（回归 #1154）")
    func nativeSwiftBoolAndNumbersUnchanged() {
        #expect(MCPJSONValue.fromFoundation(true) == .bool(true))
        #expect(MCPJSONValue.fromFoundation(false) == .bool(false))
        #expect(MCPJSONValue.fromFoundation(0) == .int(0))
        #expect(MCPJSONValue.fromFoundation(1) == .int(1))
        #expect(MCPJSONValue.object(["count": .int(0)]).jsonString() == #"{"count":0}"#)
    }
}
