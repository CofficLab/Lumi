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
