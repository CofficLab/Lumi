import Foundation

/// Anthropic 兼容 API 错误响应
struct AnthropicCompatibleErrorResponse: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let message: String
    }
}

/// Anthropic 兼容 API 非流式响应
struct AnthropicCompatibleResponse: Decodable {
    let content: [ContentBlock]

    struct ContentBlock: Decodable {
        let type: String
        let text: String?
        let id: String?
        let name: String?
        let input: [String: AnthropicCompatibleAnyValue]?
    }
}

/// 任意类型值解码器
///
/// 用于处理 Anthropic API 中 tool_use.input 等类型不确定的字段。
struct AnthropicCompatibleAnyValue: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let dictValue = try? container.decode([String: AnthropicCompatibleAnyValue].self) {
            value = dictValue.mapValues { $0.value }
        } else if let arrayValue = try? container.decode([AnthropicCompatibleAnyValue].self) {
            value = arrayValue.map { $0.value }
        } else {
            value = ""
        }
    }

    init(value: Any) {
        self.value = value
    }
}
