import Foundation
import Testing
@testable import PluginLLMProviderMLX

/// MLX 传给 chat template 的工具 Schema 必须保留 JSON 空值。
///
/// ## 为什么要有这条测试
///
/// MCP 工具的 inputSchema 通过 `JSONSerialization` 解码，JSON `null` 在
/// 那一步变成 `NSNull`。转换器此前没有处理 `NSNull`，落到
/// `default: String(describing: value)` 分支，被转成字符串 `"<null>"`。
///
/// 这破坏了 `enum` / `const` / `default` / `examples` 的语义：模型看到的
/// 是另一个 Schema，可能生成字符串 `"<null>"`，随后被 MCP 服务端的 Schema
/// 校验拒绝。
@Suite("MLX 工具 Schema 的 JSON 空值")
struct MLXSendableJSONTests {

    @Test("顶层 NSNull 转换为空值而不是字符串")
    func topLevelNullBecomesNil() {
        let converted = MLXSendableJSON.convert(NSNull())

        #expect(
            MLXSendableJSON.isNull(converted),
            "JSON null 必须保持为空值，实际 \(String(describing: converted))"
        )
        #expect(
            !(converted is String),
            "JSON null 不应变成字符串，实际 \(String(describing: converted))"
        )
    }

    @Test("enum 里的 null 保持为空值")
    func nullInEnumStaysNil() {
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "mode": [
                    "enum": [NSNull(), "auto"] as [Any],
                    "default": NSNull(),
                ] as [String: Any],
            ],
        ]

        let converted = MLXSendableJSON.convertSendableDictionary(schema)
        let properties = converted["properties"] as? [String: any Sendable]
        let mode = properties?["mode"] as? [String: any Sendable]
        let enumValues = mode?["enum"] as? [any Sendable]

        #expect(enumValues?.count == 2, "enum 的元素数量不应变化")
        let nullFlags = (enumValues ?? []).map { MLXSendableJSON.isNull($0) }
        #expect(
            nullFlags.first == true,
            "enum 里的 null 必须保持为空值，实际 \(String(describing: enumValues))"
        )
        #expect(
            nullFlags.last == false,
            "enum 里的正常值不应被当成空值"
        )
        #expect(
            enumValues?.last as? String == "auto",
            "enum 里的正常值不受影响，实际 \(String(describing: enumValues?.last))"
        )
        #expect(
            MLXSendableJSON.isNull(mode?["default"] as Any),
            "default 的 null 必须保持为空值，实际 \(String(describing: mode?["default"]))"
        )
        #expect(
            mode?["default"] != nil,
            "default 的键必须保留（删键会改变 Schema 语义）"
        )
    }

    @Test("嵌套字典里的 null 保持为空值")
    func nestedNullStaysNil() {
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "nested": ["value": NSNull()] as [String: Any],
            ],
        ]

        let converted = MLXSendableJSON.convertSendableDictionary(schema)
        let properties = converted["properties"] as? [String: any Sendable]
        let nested = properties?["nested"] as? [String: any Sendable]

        #expect(
            MLXSendableJSON.isNull(nested?["value"] as Any),
            "嵌套的 null 必须保持为空值，实际 \(String(describing: nested?["value"]))"
        )
    }

    @Test("普通值不受影响")
    func regularValuesUnchanged() {
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"] as [String: Any],
                "count": ["type": "integer"] as [String: Any],
            ],
            "required": ["name"],
        ]

        let converted = MLXSendableJSON.convertSendableDictionary(schema)

        #expect(converted["type"] as? String == "object")
        #expect((converted["properties"] as? [String: any Sendable])?["name"] != nil)
        #expect(converted["required"] as? [String] == ["name"])
    }

    @Test("NSNumber 保留为数值")
    func nsNumberStaysNumeric() {
        let converted = MLXSendableJSON.convertDictionary([
            "count": NSNumber(value: 3),
            "ratio": NSNumber(value: 0.5),
        ])

        #expect(converted["count"] as? Int == 3)
        #expect(converted["ratio"] as? Double == 0.5)
    }

    @Test("JSON null 绝不变成字符串")
    func nullNeverBecomesString() {
        let converted = MLXSendableJSON.convertDictionary([
            "value": NSNull(),
        ])

        let inner = converted["value"]
        #expect(
            !(inner is String),
            "JSON null 不应变成字符串，实际 \(String(describing: inner))"
        )
    }
}
