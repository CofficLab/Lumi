import Foundation
import Testing
@testable import PluginLLMProviderMLX

/// MCP 工具 Schema 里的数字 0/1 必须保持为数值，不能变成布尔值。
///
/// ## 为什么要有这条测试
///
/// MCP 工具的 inputSchema 经 `JSONSerialization` 解码后，JSON 数字由
/// `NSNumber` 承载。Foundation 的桥接有个坑：`NSNumber(0)` 与
/// `NSNumber(1)` 都能先成功转换为 `Bool`，而真正的 JSON boolean 是
/// `__NSCFBoolean`（CFBoolean）。
///
/// 因此若转换器先匹配 `Bool`，合法的数值 0/1 会被改写成 `false` /
/// `true`，`minimum` / `maximum` / `default` / `const` / `examples` 里的
/// 数值 0/1 全部失真——模型看到的是错误的工具契约。
@Suite("MLX 工具 Schema 的数值 0/1")
struct MLXSendableJSONNumberTests {

    @Test("JSON 数字 0 保持为数值而不是 false")
    func zeroStaysNumeric() {
        let converted = MLXSendableJSON.convert(NSNumber(value: 0))

        #expect(
            !(converted is Bool),
            "JSON 数字 0 不应变成布尔值，实际 \(converted)"
        )
        #expect(
            converted as? Int == 0,
            "JSON 数字 0 应保持数值，实际 \(String(describing: converted))"
        )
    }

    @Test("JSON 数字 1 保持为数值而不是 true")
    func oneStaysNumeric() {
        let converted = MLXSendableJSON.convert(NSNumber(value: 1))

        #expect(
            !(converted is Bool),
            "JSON 数字 1 不应变成布尔值，实际 \(converted)"
        )
        #expect(
            converted as? Int == 1,
            "JSON 数字 1 应保持数值，实际 \(String(describing: converted))"
        )
    }

    @Test("JSON 布尔值仍然是布尔值")
    func booleansStayBoolean() {
        let trueValue = MLXSendableJSON.convert(NSNumber(value: 1)) // 占位，下面用真实布尔替换
        _ = trueValue

        // 用 JSONSerialization 产生真正的 __NSCFBoolean。
        let decoded = try? JSONSerialization.jsonObject(
            with: Data(#"{"t":true,"f":false}"#.utf8)
        ) as? [String: Any]
        let dictionary = decoded ?? [:]

        let convertedTrue = MLXSendableJSON.convert(dictionary["t"])
        let convertedFalse = MLXSendableJSON.convert(dictionary["f"])

        #expect(convertedTrue as? Bool == true, "JSON true 应保持布尔值")
        #expect(convertedFalse as? Bool == false, "JSON false 应保持布尔值")
    }

    @Test("Schema 里的 minimum/default 为 0 时保持数值")
    func schemaNumbersStayNumeric() {
        let decoded = try? JSONSerialization.jsonObject(
            with: Data(#"""
            {"type":"object","properties":{"count":{"type":"integer","minimum":1,"default":0}}}
            """#.utf8)
        ) as? [String: Any]
        let schema = decoded ?? [:]

        let converted = MLXSendableJSON.convertSendableDictionary(schema)
        let properties = converted["properties"] as? [String: any Sendable]
        let count = properties?["count"] as? [String: any Sendable]

        #expect(
            count?["minimum"] as? Int == 1,
            "minimum 应保持数值，实际 \(String(describing: count?["minimum"]))"
        )
        #expect(
            count?["default"] as? Int == 0,
            "default 应保持数值，实际 \(String(describing: count?["default"]))"
        )
        #expect(
            !(count?["default"] is Bool),
            "default 不应变成布尔值"
        )
    }

    @Test("数组里的 0/1 也保持数值")
    func arrayNumbersStayNumeric() {
        let decoded = try? JSONSerialization.jsonObject(
            with: Data(#"{"values":[0,1,2]}"#.utf8)
        ) as? [String: Any]
        let dictionary = decoded ?? [:]

        let converted = MLXSendableJSON.convert(dictionary["values"])
        let values = converted as? [any Sendable]

        #expect(values?.count == 3)
        #expect(
            !(values?.first is Bool),
            "数组里的 0 不应变成布尔值，实际 \(String(describing: values?.first))"
        )
        #expect(
            values?.first as? Int == 0,
            "数组里的 0 应保持数值"
        )
        #expect(
            values?.dropFirst().first as? Int == 1,
            "数组里的 1 应保持数值"
        )
    }
}
