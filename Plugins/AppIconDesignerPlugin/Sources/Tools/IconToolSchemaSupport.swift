import Foundation
import LumiCoreKit

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
