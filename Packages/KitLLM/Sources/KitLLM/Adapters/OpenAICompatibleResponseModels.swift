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
