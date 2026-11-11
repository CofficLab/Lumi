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

        // 必须先判空：JSON `null` 会让后面所有具体解码都失败，最后落到
        // 兜底的 `value = ""`——工具调用照常发出，但参数里已经没有模型
        // 返回的值了（`{"value":null}` 变成 `{"value":""}`）。
        //
        // 用 `null` 表示「缺省 / 清空可选字段」的 Anthropic 工具会收到
        // 字符串：严格校验失败，宽松校验则可能执行与模型意图不同的操作。
        if container.decodeNil() {
            value = NSNull()
        } else if let intValue = try? container.decode(Int.self) {
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
