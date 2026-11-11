import Foundation

struct OpenAICompatibleErrorResponse: Decodable {
    let error: APIError

    struct APIError: Decodable {
        let message: String
    }
}

struct OpenAICompatibleResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String?
        let toolCalls: [ToolCallData]?
        let reasoningContent: String?
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
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            content = try container.decodeIfPresent(String.self, forKey: .content)
            toolCalls = try container.decodeIfPresent([ToolCallData].self, forKey: .toolCalls)
            refusal = try container.decodeIfPresent(String.self, forKey: .refusal)
            // 两个别名都支持：优先 `reasoning_content`，其次 `reasoning`。
            reasoningContent = try container.decodeIfPresent(String.self, forKey: .reasoningContent)
                ?? container.decodeIfPresent(String.self, forKey: .reasoning)
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
