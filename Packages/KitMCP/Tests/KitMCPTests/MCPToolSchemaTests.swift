import Foundation
import Testing
@testable import KitMCP

/// 工具 schema 预解析的行为契约（Issue #1275）。
///
/// 核心诉求：MCP 工具的 schema 在 `listTools` 之后是静态的，解析与规范化
/// 应当只发生一次，之后每次访问都是零成本。
@Suite("MCPToolSchema 预解析")
struct MCPToolSchemaTests {

    // MARK: - 正确性

    @Test("解析结果与 JSONSerialization 直接解析一致")
    func parametersMatchDirectParsing() throws {
        let json = #"{"type":"object","properties":{"a":{"type":"string"}},"required":["a"]}"#
        let schema = MCPToolSchema(json: json)

        let expected = try #require(
            try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        )
        #expect(schema.parameters != nil)
        #expect(NSDictionary(dictionary: schema.parameters ?? [:])
            .isEqual(to: expected))
    }

    @Test("规范化文本与直接序列化一致")
    func normalizedJSONMatchesDirectSerialization() throws {
        let json = #"{"type":"object","properties":{"zebra":{"type":"string"},"alpha":{"type":"number"}}}"#
        let schema = MCPToolSchema(json: json)

        let expected = String(
            data: try JSONSerialization.data(
                withJSONObject: try #require(try? JSONSerialization.jsonObject(with: Data(json.utf8))),
                options: [.sortedKeys]
            ),
            encoding: .utf8
        )
        #expect(schema.normalizedJSON == expected)
    }

    @Test("非法 JSON 时参数与规范化文本均为 nil")
    func invalidJSONYieldsNil() {
        let schema = MCPToolSchema(json: "not json!!!")

        #expect(schema.parameters == nil)
        #expect(schema.normalizedJSON == nil)
        #expect(schema.normalizedByteCount == 0)
    }

    @Test("解析失败时回退到空 schema")
    func invalidJSONFallsBackToEmptyParameters() {
        let schema = MCPToolSchema(json: "not json!!!")

        #expect(schema.resolvedParameters["type"] as? String == "object")
        #expect(schema.resolvedParameters["properties"] != nil)
    }

    @Test("空 schema 解析为合法对象")
    func emptyJSONObjectParses() throws {
        let schema = MCPToolSchema(json: "{}")

        #expect(schema.parameters != nil)
        #expect(schema.normalizedJSON == "{}")
    }

    @Test("规范化字节数等于规范化文本长度")
    func byteCountMatchesNormalizedText() {
        let json = #"{"type":"object","properties":{"a":{"type":"string"}}}"#
        let schema = MCPToolSchema(json: json)

        #expect(schema.normalizedByteCount == (schema.normalizedJSON?.utf8.count ?? -1))
    }

    // MARK: - 描述符接入

    @Test("描述符的 inputSchemaDictionary 返回预解析结果")
    func descriptorReturnsPreparsedSchema() throws {
        let json = #"{"type":"object","properties":{"a":{"type":"string"}}}"#
        let descriptor = MCPToolDescriptor(name: "tool", inputSchemaJSON: json)

        let dictionary = try #require(descriptor.inputSchemaDictionary())
        #expect(dictionary["type"] as? String == "object")
        #expect(descriptor.schema.normalizedJSON != nil)
    }

    @Test("描述符的相等性只看原始字段")
    func descriptorEqualityIgnoresDerivedSchema() {
        let json = #"{"type":"object"}"#
        let first = MCPToolDescriptor(name: "tool", inputSchemaJSON: json)
        let second = MCPToolDescriptor(name: "tool", inputSchemaJSON: json)

        #expect(first == second)
    }

    @Test("描述符的相等性能区分不同 schema")
    func descriptorEqualityDistinguishesSchemas() {
        let first = MCPToolDescriptor(name: "tool", inputSchemaJSON: #"{"type":"object"}"#)
        let second = MCPToolDescriptor(name: "tool", inputSchemaJSON: #"{"type":"array"}"#)

        #expect(first != second)
    }

    @Test("重复访问描述符的 schema 不会改变内容")
    func repeatedAccessIsStable() throws {
        let json = #"{"type":"object","properties":{"a":{"type":"string"}}}"#
        let descriptor = MCPToolDescriptor(name: "tool", inputSchemaJSON: json)

        let first = try #require(descriptor.inputSchemaDictionary())
        let second = try #require(descriptor.inputSchemaDictionary())

        #expect(NSDictionary(dictionary: first).isEqual(to: second))
    }

    // MARK: - 性能回归

    @Test("重复读取 schema 的耗时显著低于首次解析")
    func repeatedAccessIsCheaperThanParsing() {
        // 约 700 字节的真实规模 schema。
        let properties = (0..<12).map { index in
            "\"prop\(index)\":{\"type\":\"string\",\"description\":\"参数 \(index) 的说明文本\"}"
        }.joined(separator: ",")
        let json = "{\"type\":\"object\",\"properties\":{\(properties)},\"required\":[\"prop0\"]}"
        let descriptor = MCPToolDescriptor(name: "tool", inputSchemaJSON: json)

        let iterations = 200

        let parseStart = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            _ = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        }
        let parseElapsed = DispatchTime.now().uptimeNanoseconds - parseStart

        let cachedStart = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            _ = descriptor.inputSchemaDictionary()
        }
        let cachedElapsed = DispatchTime.now().uptimeNanoseconds - cachedStart

        // 预解析后必须明显更快；放宽到「至少快 2 倍」以稳定抓住回归。
        #expect(cachedElapsed * 2 < parseElapsed)
    }
}
