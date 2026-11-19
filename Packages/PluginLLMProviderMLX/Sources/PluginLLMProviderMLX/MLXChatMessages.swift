import Foundation
import KitLLM
import MLXLMCommon

/// `LLMRequest` 消息到 MLX `Chat.Message` 的桥接。
enum MLXChatMessages {
    /// 按消息位置分配图片（#412）：每条 user 消息保留各自的图片，
    /// 而不是只保留最后一条——否则多轮对话里早期回合的图像全部丢失，
    /// 模型无法继续回答关于首图的问题。`imageURLsByMessageIndex` 由
    /// 调用方先把图片字节写入临时文件后按消息下标组装。
    static func build(
        from messages: [LLMMessage],
        imageURLsByMessageIndex: [Int: [URL]]
    ) -> [Chat.Message] {
        messages.enumerated().compactMap { index, message -> Chat.Message? in
            switch message.role {
            case .system: return .system(message.content)
            case .user:
                let images = (imageURLsByMessageIndex[index] ?? []).map { UserInput.Image.url($0) }
                return images.isEmpty ? .user(message.content) : .user(message.content, images: images)
            case .assistant: return .assistant(message.content)
            default: return nil
            }
        }
    }
}
