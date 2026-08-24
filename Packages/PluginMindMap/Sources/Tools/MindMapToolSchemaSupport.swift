import Foundation
import KernelLumi

// 为 `LumiJSONValue` 补齐字面量构造能力，使工具的 inputSchema 可用 Swift 字典字面量
// 直接表达 JSON Schema（与 IconToolSchemaSupport 同构）。

extension LumiJSONValue: @retroactive ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}

extension LumiJSONValue: @retroactive ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .int(value) }
}

extension LumiJSONValue: @retroactive ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .double(value) }
}

extension LumiJSONValue: @retroactive ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension LumiJSONValue: @retroactive ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: LumiJSONValue...) { self = .array(elements) }
}

extension LumiJSONValue: @retroactive ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, LumiJSONValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}
