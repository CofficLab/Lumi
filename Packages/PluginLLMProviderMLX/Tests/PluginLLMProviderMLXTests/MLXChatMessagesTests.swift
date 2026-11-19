import Foundation
import KitLLM
import Testing
import MLXLMCommon
@testable import PluginLLMProviderMLX

/// MLX 历史消息图片桥接（Issue #412）。
///
/// 只把最后一条 user 消息的图片传给 MLX、其余历史消息强制清空图片，
/// 会让多轮对话里早期回合的图像全部丢失：模型看到「第二轮没有图」，
/// 无法继续回答关于第一轮图片的问题。
@Suite("MLX 历史消息图片桥接")
struct MLXChatMessagesTests {

    private let firstImage = MessageImage(data: Data(repeating: 0x42, count: 16), mimeType: "image/png")
    private let secondImage = MessageImage(data: Data(repeating: 0x43, count: 16), mimeType: "image/jpeg")

    private func imageSourceURL(_ image: UserInput.Image) -> URL? {
        if case .url(let url) = image.source { return url }
        return nil
    }

    @Test("历史 user 消息保留各自的图片，最后一条也不多不少")
    func historyImagesSurviveByPosition() {
        let messages: [LLMMessage] = [
            LLMMessage(role: .user, content: "第一轮", images: [firstImage]),
            LLMMessage(role: .assistant, content: "好的"),
            LLMMessage(role: .user, content: "第二轮"),
        ]
        let imageURLsByMessageIndex: [Int: [URL]] = [
            0: [URL(fileURLWithPath: "/tmp/lumi-mlx-0-0.png")],
        ]

        let chat = MLXChatMessages.build(from: messages, imageURLsByMessageIndex: imageURLsByMessageIndex)

        #expect(chat.count == 3)
        #expect(chat[0].role == .user)
        #expect(chat[0].content == "第一轮")
        #expect(chat[0].images.count == 1)
        #expect(chat[1].role == .assistant)
        #expect(chat[1].images.isEmpty)
        #expect(chat[2].role == .user)
        #expect(chat[2].content == "第二轮")
        #expect(chat[2].images.isEmpty)
    }

    @Test("多轮各自带图时按消息位置对应，不串图")
    func perTurnImagesMapToOwnMessage() {
        let messages: [LLMMessage] = [
            LLMMessage(role: .user, content: "第一轮", images: [firstImage]),
            LLMMessage(role: .user, content: "第二轮", images: [secondImage]),
        ]
        let imageURLsByMessageIndex: [Int: [URL]] = [
            0: [URL(fileURLWithPath: "/tmp/lumi-mlx-0-0.png")],
            1: [URL(fileURLWithPath: "/tmp/lumi-mlx-1-0.jpg")],
        ]

        let chat = MLXChatMessages.build(from: messages, imageURLsByMessageIndex: imageURLsByMessageIndex)

        #expect(imageSourceURL(chat[0].images[0])?.absoluteString == "file:///tmp/lumi-mlx-0-0.png")
        #expect(imageSourceURL(chat[1].images[0])?.absoluteString == "file:///tmp/lumi-mlx-1-0.jpg")
    }

    @Test("system 与 tool 消息的映射保持不变")
    func systemAndToolMappingUnchanged() {
        let messages: [LLMMessage] = [
            LLMMessage(role: .system, content: "you are helpful"),
            LLMMessage(role: .user, content: "hi"),
            LLMMessage(role: .tool, content: "result", toolCallID: "call-1"),
        ]

        let chat = MLXChatMessages.build(from: messages, imageURLsByMessageIndex: [:])

        #expect(chat.count == 2)
        #expect(chat[0].role == .system)
        #expect(chat[0].content == "you are helpful")
        #expect(chat[1].role == .user)
    }
}
