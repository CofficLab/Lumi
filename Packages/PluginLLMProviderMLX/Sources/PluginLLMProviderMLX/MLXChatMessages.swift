import Foundation
import KitLLM
import MLXLMCommon

/// `LLMRequest` 消息到 MLX `Chat.Message` 的桥接。
enum MLXChatMessages {
    /// 按消息位置分配图片（#412）：每条 user 消息保留各自的图片，
    /// 而不是只保留最后一条——否则多轮对话里早期回合的图像全部丢失，
    /// 模型无法继续回答关于首图的问题。`imageURLsByMessageIndex` 由
    /// 调用方先把图片字节写入临时文件后按消息下标组装。
    ///
    /// 工具历史同样必须进提示词（#286）：assistant 的 toolCalls 与对应
    /// 的 tool 结果此前被整体丢弃，模型每轮都重新收到工具定义、却看不到
    /// 上一轮的调用与输出，于是重复调用或无视工具结果直接作答。
    /// 参数解析失败时降级为空对象并保留调用本身，避免丢失对应关系。
    static func build(
        from messages: [LLMMessage],
        imageURLsByMessageIndex: [Int: [URL]]
    ) -> [Chat.Message] {
        // 部分模板（如 Onyx）直接按函数名渲染工具结果，而不读 tool_call_id。
        let toolNamesByCallID = Dictionary(
            messages.flatMap { $0.toolCalls ?? [] }.map { ($0.id, $0.name) },
            uniquingKeysWith: { _, new in new }
        )
        return messages.enumerated().compactMap { index, message -> Chat.Message? in
            switch message.role {
            case .system: return .system(message.content)
            case .user:
                let images = (imageURLsByMessageIndex[index] ?? []).map { UserInput.Image.url($0) }
                return images.isEmpty ? .user(message.content) : .user(message.content, images: images)
            case .assistant:
                let calls = (message.toolCalls ?? []).compactMap { call -> MLXLMCommon.ToolCall? in
                    let arguments = (try? JSONDecoder().decode(
                        [String: JSONValue].self,
                        from: Data(call.arguments.utf8)
                    )) ?? [:]
                    return MLXLMCommon.ToolCall(
                        function: .init(name: call.name, arguments: arguments),
                        id: call.id
                    )
                }
                return .assistant(message.content, toolCalls: calls.isEmpty ? nil : calls)
            case .tool:
                let name = message.toolCallID.flatMap { toolNamesByCallID[$0] }
                return .tool(message.content, id: message.toolCallID, name: name)
            default: return nil
            }
        }
    }
}
