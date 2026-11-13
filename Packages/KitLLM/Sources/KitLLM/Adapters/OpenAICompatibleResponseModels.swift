import Foundation

struct OpenAICompatibleErrorResponse: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let message: String
    }
}

struct OpenAICompatibleResponse: Decodable {
    let choices: [Choice]
    /// 顶层响应 ID（`chatcmpl-...`）。
    ///
    /// 这是供应商的关联标识，下游要靠它把一次请求与它的日志对上。
    let id: String?
    /// token 用量。
    ///
    /// 随响应一起解码，而不是事后用 `JSONSerialization` 把同一份响应
    /// 再解析一遍只为读 `usage`——那一步占了大响应解析开销的近六成
    /// （Issue #1270）。
    let usage: Usage?

    /// token 用量。
    ///
    /// 各家供应商的字段名不统一（`prompt_tokens` / `input_tokens`、
    /// `completion_tokens` / `output_tokens`…），缓存相关的计数还嵌在
    /// `*_tokens_details` 里。这里用**宽松解码**：所有字段都可选，缺失
    /// 即为 `nil`，由调用方按既有规则回退。
    struct Usage: Decodable {
        let promptTokens: Int?
        let inputTokens: Int?
        let completionTokens: Int?
        let outputTokens: Int?
        let totalTokens: Int?
        let cachedInputTokens: Int?
        let cacheWriteTokens: Int?
        let cacheCreationInputTokens: Int?
        /// 缓存读计数（OpenAI 形态：`prompt_tokens_details.cached_tokens`）。
        let promptTokensDetailsCachedTokens: Int?
        /// 缓存写计数（OpenRouter 形态，嵌在 `prompt_tokens_details`）。
        let promptTokensDetailsCacheWriteTokens: Int?
        /// 缓存读计数（嵌在 `input_tokens_details`）。
        let inputTokensDetailsCachedTokens: Int?
        /// 缓存写计数（Anthropic 形态，嵌在 `prompt_tokens_details`）。
        let promptTokensDetailsCacheCreationInputTokens: Int?
        /// 缓存写计数（Anthropic 形态，嵌在 `input_tokens_details`）。
        let inputTokensDetailsCacheCreationInputTokens: Int?
        /// 缓存写计数（Anthropic 形态，嵌在 `input_tokens_details`）。
        let inputTokensDetailsCacheWriteTokens: Int?
        /// 缓存读计数（Anthropic 形态：`cache_read_input_tokens`）。
        let cacheReadInputTokens: Int?
        /// 缓存读计数（DeepSeek OpenAI API 形态：`prompt_cache_hit_tokens`）。
        let promptCacheHitTokens: Int?
        /// 缓存读计数（部分网关直接放在 usage 顶层：`cached_tokens`）。
        let cachedTokens: Int?
        /// 输入 token 数（部分网关形态：`prompt_token_count`）。
        let promptTokenCount: Int?
        /// 输入 token 数（部分网关形态：`input_token_count`）。
        let inputTokenCount: Int?
        /// 输出 token 数（部分网关形态：`candidates_token_count`）。
        let candidatesTokenCount: Int?
        /// 输出 token 数（部分网关形态：`output_token_count`）。
        let outputTokenCount: Int?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case inputTokens = "input_tokens"
            case completionTokens = "completion_tokens"
            case outputTokens = "output_tokens"
            case totalTokens = "total_tokens"
            case cachedInputTokens = "cached_input_tokens"
            case cacheWriteTokens = "cache_write_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
            case promptCacheHitTokens = "prompt_cache_hit_tokens"
            case cachedTokens = "cached_tokens"
            case promptTokenCount = "prompt_token_count"
            case inputTokenCount = "input_token_count"
            case candidatesTokenCount = "candidates_token_count"
            case outputTokenCount = "output_token_count"
            case promptTokensDetails = "prompt_tokens_details"
            case inputTokensDetails = "input_tokens_details"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            promptTokens = try container.decodeIfPresent(Int.self, forKey: .promptTokens)
            inputTokens = try container.decodeIfPresent(Int.self, forKey: .inputTokens)
            completionTokens = try container.decodeIfPresent(Int.self, forKey: .completionTokens)
            outputTokens = try container.decodeIfPresent(Int.self, forKey: .outputTokens)
            totalTokens = try container.decodeIfPresent(Int.self, forKey: .totalTokens)
            cachedInputTokens = try container.decodeIfPresent(Int.self, forKey: .cachedInputTokens)
            cacheWriteTokens = try container.decodeIfPresent(Int.self, forKey: .cacheWriteTokens)
            cacheCreationInputTokens = try container.decodeIfPresent(Int.self, forKey: .cacheCreationInputTokens)
            cacheReadInputTokens = try container.decodeIfPresent(Int.self, forKey: .cacheReadInputTokens)
            promptCacheHitTokens = try container.decodeIfPresent(Int.self, forKey: .promptCacheHitTokens)
            cachedTokens = try container.decodeIfPresent(Int.self, forKey: .cachedTokens)
            promptTokenCount = try container.decodeIfPresent(Int.self, forKey: .promptTokenCount)
            inputTokenCount = try container.decodeIfPresent(Int.self, forKey: .inputTokenCount)
            candidatesTokenCount = try container.decodeIfPresent(Int.self, forKey: .candidatesTokenCount)
            outputTokenCount = try container.decodeIfPresent(Int.self, forKey: .outputTokenCount)

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
        ///
        /// 用自定义 init 让三个字段全部可选：不同网关只会给其中一部分。
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


    struct Choice: Decodable {
        let message: Message
        /// 结束原因（`stop` / `length` / `tool_calls` 等）。
        ///
        /// 截断的回答（`length`）靠它才能说明「为什么没说完」。
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }

    struct Message: Decodable {
        let content: String?
        let toolCalls: [ToolCallData]?
        let reasoningContent: String?
        /// 生成的图片（图像生成模型的产物）。
        let images: [ImageData]?
        /// 模型拒答文本（OpenAI 的 `message.refusal`）。
        ///
        /// 拒答时 `content` 为 `null`，拒答说明只出现在这个字段里。
        /// 不解析它会让一次合法的拒答变成空响应。
        let refusal: String?

        enum CodingKeys: String, CodingKey {
            case content
            case toolCalls = "tool_calls"
            case reasoningContent = "reasoning_content"
            case refusal
            /// OpenRouter 把助手的思考放在 `reasoning` 字段上，
            /// 与其它供应商的 `reasoning_content` 是同一个语义。
            case reasoning
            case images
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            content = try container.decodeIfPresent(String.self, forKey: .content)
            toolCalls = try container.decodeIfPresent([ToolCallData].self, forKey: .toolCalls)
            refusal = try container.decodeIfPresent(String.self, forKey: .refusal)
            // 两个别名都支持：优先 `reasoning_content`，其次 `reasoning`。
            reasoningContent = try container.decodeIfPresent(String.self, forKey: .reasoningContent)
                ?? container.decodeIfPresent(String.self, forKey: .reasoning)
            images = try container.decodeIfPresent([ImageData].self, forKey: .images)
        }
    }

    /// OpenAI 兼容协议里的图片条目。
    ///
    /// 图像生成模型（OpenRouter 的 Seedream 等）返回
    /// `{"type": "image_url", "image_url": {"url": "data:image/png;base64,..."}}`。
    struct ImageData: Decodable {
        let type: String?
        let imageURL: ImageURLData?

        enum CodingKeys: String, CodingKey {
            case type
            case imageURL = "image_url"
        }

        struct ImageURLData: Decodable {
            let url: String?
        }

        /// 解码成 `MessageImage`；非 data URL 或解码失败时返回 `nil`。
        ///
        /// 只支持 `data:` URL：OpenAI 兼容协议的图片条目目前只内联 base64，
        /// 外链 URL 无法在不额外下载的前提下变成图片数据。
        func decodedImage() -> MessageImage? {
            guard let url = imageURL?.url, url.hasPrefix("data:") else { return nil }
            guard let commaIndex = url.firstIndex(of: ",") else { return nil }
            let metadata = String(url[url.startIndex..<commaIndex])
            let payload = String(url[url.index(after: commaIndex)...])
            guard metadata.contains("base64"), let data = Data(base64Encoded: payload) else { return nil }
            let mimeType = String(metadata.dropFirst("data:".count).prefix(while: { $0 != ";" }))
            return MessageImage(data: data, mimeType: mimeType.isEmpty ? "image/png" : mimeType)
        }
    }

    struct ToolCallData: Decodable {
        let id: String
        let function: Function

        struct Function: Decodable {
            let name: String
            let arguments: String
        }
    }
}
