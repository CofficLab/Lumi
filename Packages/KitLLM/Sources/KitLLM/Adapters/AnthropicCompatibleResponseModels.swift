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
    /// 响应 ID（`msg_...`）。
    let id: String?
    /// 停止原因（`end_turn` / `tool_use` / `max_tokens` 等）。
    let stopReason: String?
    /// token 用量。
    let usage: Usage?

    enum CodingKeys: String, CodingKey {
        case content, id
        case stopReason = "stop_reason"
        case usage
    }

    /// Anthropic 的 usage 结构。
    ///
    /// 除了 Anthropic 原生字段，还解码各家兼容网关用到的**别名**
    /// （`prompt_tokens` / `completion_tokens` / `cached_tokens` /
    /// `*_tokens_details` …）。这些别名此前由 `tokenCounts(from:)` 用
    /// `JSONSerialization` 把整份响应重解析一遍才读得到——现在随响应
    /// 一起解码，省掉那次重解析（Issue #1270）。
    ///
    /// 字段全部可选：不同端点只给其中一部分，缺失即 `nil`。
    struct Usage: Decodable {
        let inputTokens: Int?
        let outputTokens: Int?
        let cacheCreationInputTokens: Int?
        let cacheReadInputTokens: Int?

        // 别名字段（兼容网关形态）。
        let promptTokens: Int?
        let completionTokens: Int?
        let cachedInputTokens: Int?
        let cacheWriteTokens: Int?
        let promptTokenCount: Int?
        let inputTokenCount: Int?
        let candidatesTokenCount: Int?
        let outputTokenCount: Int?
        let promptCacheHitTokens: Int?
        let cachedTokens: Int?
        let promptTokensDetailsCachedTokens: Int?
        let promptTokensDetailsCacheWriteTokens: Int?
        let promptTokensDetailsCacheCreationInputTokens: Int?
        let inputTokensDetailsCachedTokens: Int?
        let inputTokensDetailsCacheWriteTokens: Int?
        let inputTokensDetailsCacheCreationInputTokens: Int?

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case cachedInputTokens = "cached_input_tokens"
            case cacheWriteTokens = "cache_write_tokens"
            case promptTokenCount = "prompt_token_count"
            case inputTokenCount = "input_token_count"
            case candidatesTokenCount = "candidates_token_count"
            case outputTokenCount = "output_token_count"
            case promptCacheHitTokens = "prompt_cache_hit_tokens"
            case cachedTokens = "cached_tokens"
            case promptTokensDetails = "prompt_tokens_details"
            case inputTokensDetails = "input_tokens_details"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            inputTokens = try container.decodeIfPresent(Int.self, forKey: .inputTokens)
            outputTokens = try container.decodeIfPresent(Int.self, forKey: .outputTokens)
            cacheCreationInputTokens = try container.decodeIfPresent(Int.self, forKey: .cacheCreationInputTokens)
            cacheReadInputTokens = try container.decodeIfPresent(Int.self, forKey: .cacheReadInputTokens)
            promptTokens = try container.decodeIfPresent(Int.self, forKey: .promptTokens)
            completionTokens = try container.decodeIfPresent(Int.self, forKey: .completionTokens)
            cachedInputTokens = try container.decodeIfPresent(Int.self, forKey: .cachedInputTokens)
            cacheWriteTokens = try container.decodeIfPresent(Int.self, forKey: .cacheWriteTokens)
            promptTokenCount = try container.decodeIfPresent(Int.self, forKey: .promptTokenCount)
            inputTokenCount = try container.decodeIfPresent(Int.self, forKey: .inputTokenCount)
            candidatesTokenCount = try container.decodeIfPresent(Int.self, forKey: .candidatesTokenCount)
            outputTokenCount = try container.decodeIfPresent(Int.self, forKey: .outputTokenCount)
            promptCacheHitTokens = try container.decodeIfPresent(Int.self, forKey: .promptCacheHitTokens)
            cachedTokens = try container.decodeIfPresent(Int.self, forKey: .cachedTokens)

            let promptDetails = try container.decodeIfPresent(
                TokenDetails.self, forKey: .promptTokensDetails
            )
            promptTokensDetailsCachedTokens = promptDetails?.cachedTokens
            promptTokensDetailsCacheWriteTokens = promptDetails?.cacheWriteTokens
            promptTokensDetailsCacheCreationInputTokens = promptDetails?.cacheCreationInputTokens

            let inputDetails = try container.decodeIfPresent(
                TokenDetails.self, forKey: .inputTokensDetails
            )
            inputTokensDetailsCachedTokens = inputDetails?.cachedTokens
            inputTokensDetailsCacheWriteTokens = inputDetails?.cacheWriteTokens
            inputTokensDetailsCacheCreationInputTokens = inputDetails?.cacheCreationInputTokens
        }

        /// `*_tokens_details` 子对象。
        struct TokenDetails: Decodable {
            let cachedTokens: Int?
            let cacheWriteTokens: Int?
            let cacheCreationInputTokens: Int?

            enum CodingKeys: String, CodingKey {
                case cachedTokens = "cached_tokens"
                case cacheWriteTokens = "cache_write_tokens"
                case cacheCreationInputTokens = "cache_creation_input_tokens"
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                cachedTokens = try container.decodeIfPresent(Int.self, forKey: .cachedTokens)
                cacheWriteTokens = try container.decodeIfPresent(Int.self, forKey: .cacheWriteTokens)
                cacheCreationInputTokens = try container.decodeIfPresent(Int.self, forKey: .cacheCreationInputTokens)
            }
        }
    }

    struct ContentBlock: Decodable {
        let type: String
        let text: String?
        let id: String?
        let name: String?
        let input: [String: AnthropicCompatibleAnyValue]?
        /// `redacted_thinking` 块的不透明密文，必须原样回传（#1167）。
        let data: String?
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
