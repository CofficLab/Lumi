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

    @Test("tool 消息带 id/name 进入历史，未知角色仍丢弃")
    func systemAndToolMapping() {
        let messages: [LLMMessage] = [
            LLMMessage(role: .system, content: "you are helpful"),
            LLMMessage(role: .user, content: "hi"),
            LLMMessage(role: .tool, content: "result", toolCallID: "call-1"),
        ]

        let chat = MLXChatMessages.build(from: messages, imageURLsByMessageIndex: [:])

        #expect(chat.count == 3)
        #expect(chat[0].role == .system)
        #expect(chat[0].content == "you are helpful")
        #expect(chat[1].role == .user)
        #expect(chat[2].role == .tool)
        #expect(chat[2].content == "result")
    }

    /// 与 chat template 实际消费的原始字典断言（tool_calls / tool_call_id / name）。
    private func rawMessages(from chat: [Chat.Message]) -> [[String: any Sendable]] {
        DefaultMessageGenerator().generate(messages: chat)
    }

    @Test("assistant 的 toolCalls 与对应工具结果进入提示词历史（#286）")
    func toolHistorySurvivesIntoPrompt() {
        let messages: [LLMMessage] = [
            LLMMessage(role: .user, content: "东京天气如何？"),
            LLMMessage(
                role: .assistant,
                content: "",
                toolCalls: [LLMToolCall(id: "call-1", name: "get_weather", arguments: #"{"city":"Tokyo"}"#)]
            ),
            LLMMessage(role: .tool, content: "22°C 晴", toolCallID: "call-1"),
            LLMMessage(role: .assistant, content: "东京 22°C，晴。"),
        ]

        let chat = MLXChatMessages.build(from: messages, imageURLsByMessageIndex: [:])

        #expect(chat.count == 4)
        #expect(chat[1].role == .assistant)
        #expect(chat[2].role == .tool)
        #expect(chat[2].content == "22°C 晴")

        let raw = rawMessages(from: chat)
        let calls = raw[1]["tool_calls"] as? [[String: any Sendable]]
        #expect(calls?.count == 1, "assistant 历史必须携带 tool_calls，实际 \(raw[1])")
        let function = calls?[0]["function"] as? [String: any Sendable]
        #expect(function?["name"] as? String == "get_weather")
        let arguments = function?["arguments"] as? [String: any Sendable]
        #expect(arguments?["city"] as? String == "Tokyo")
        #expect(calls?[0]["id"] as? String == "call-1")

        let toolRaw = raw[2]
        #expect(toolRaw["role"] as? String == "tool")
        #expect(toolRaw["tool_call_id"] as? String == "call-1")
        // 工具结果按 tool_call_id 关联到 assistant 调用里的函数名。
        #expect(toolRaw["name"] as? String == "get_weather")
    }

    @Test("只有能进入提示词的角色才参与历史与缓存前缀比较")
    func promptMessageRoles() {
        #expect(MLXChatMessages.isPromptMessage(LLMMessage(role: .system, content: "s")))
        #expect(MLXChatMessages.isPromptMessage(LLMMessage(role: .user, content: "u")))
        #expect(MLXChatMessages.isPromptMessage(LLMMessage(role: .assistant, content: "a")))
        #expect(MLXChatMessages.isPromptMessage(LLMMessage(role: .tool, content: "t", toolCallID: "id")))
        #expect(!MLXChatMessages.isPromptMessage(LLMMessage(role: .status, content: "运行中")))
        #expect(!MLXChatMessages.isPromptMessage(LLMMessage(role: .error, content: "失败")))
        #expect(!MLXChatMessages.isPromptMessage(LLMMessage(role: .unknown, content: "?")))
    }

    @Test("参数解析失败时保留调用并降级为空对象（#286）")
    func malformedArgumentsDegradeToEmptyObject() {
        let messages: [LLMMessage] = [
            LLMMessage(
                role: .assistant,
                content: "",
                toolCalls: [LLMToolCall(id: "call-9", name: "get_weather", arguments: "not-json")]
            ),
        ]

        let chat = MLXChatMessages.build(from: messages, imageURLsByMessageIndex: [:])

        #expect(chat.count == 1)
        let raw = rawMessages(from: chat)
        let calls = raw[0]["tool_calls"] as? [[String: any Sendable]]
        #expect(calls?.count == 1)
        let function = calls?[0]["function"] as? [String: any Sendable]
        #expect((function?["arguments"] as? [String: any Sendable])?.isEmpty == true)
    }
}
