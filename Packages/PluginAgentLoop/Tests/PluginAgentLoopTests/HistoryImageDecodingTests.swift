import Foundation
import KitLLM
import ProviderMessage
import Testing
@testable import PluginAgentLoop

/// 历史图片解码的契约（Issue #1268）。
///
/// 两条核心要求：
/// 1. 非视觉模型（`supportsVision == false`）**不解码任何图片字节**——
///    此前是「先解码再剥离」，图片白白解码一遍随即丢弃。
/// 2. 历史转换**不在主线程上同步执行**。
///
/// 用例通过解码器的原子计数器观察「图片字节在什么时刻、哪个线程上被
/// 处理」。计数器是进程内共享的，因此断言用**差值**（本用例期间的新增量）
/// 而不是绝对值——这样用例之间可以并行运行而互不干扰。
@Suite("历史图片解码与离主线程转换")
struct HistoryImageDecodingTests {

    /// 解码计数器的快照。
    private struct CounterSnapshot {
        let count: Int
        let mainThreadCount: Int
    }

    /// 读取当前计数。
    private func snapshot(of decoder: ImageBase64Decoder) -> CounterSnapshot {
        let counter = decoder.decodeCounter
        return CounterSnapshot(count: counter.count, mainThreadCount: counter.mainThreadCount)
    }

    /// 构造一条带图片附件的 user 消息。
    private func userMessageWithImage(
        conversationID: UUID,
        imageData: Data
    ) -> Message {
        let attachment = UserImageAttachment(
            mimeType: "image/png",
            base64Data: imageData.base64EncodedString()
        )
        return Message(
            conversationID: conversationID,
            role: .user,
            content: "看图",
            metadata: UserAttachmentMetadata.encodeImageAttachments([attachment])
        )
    }

    /// 构造一条带图片工具结果的 assistant 消息 + 配对的 tool 消息。
    private func assistantAndToolMessagesWithImage(
        conversationID: UUID,
        imageData: Data
    ) -> (Message, Message) {
        let assistant = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            toolCalls: [
                MessageToolCall(
                    id: "call-image",
                    name: "read_image",
                    arguments: "{}",
                    result: MessageToolResult(
                        content: "已读取图片",
                        imageAttachments: [
                            MessageImageAttachment(data: imageData.base64EncodedString(), mimeType: "image/png")
                        ]
                    )
                )
            ]
        )
        let tool = Message(
            conversationID: conversationID,
            role: .tool,
            content: "图",
            toolCallID: "call-image"
        )
        return (assistant, tool)
    }

    // MARK: - 非视觉模型不解码

    @Test("非视觉模式（includesImages 为 false）不解码用户图片附件")
    func nonVisionModeDoesNotDecodeUserImages() {
        let conversationID = UUID()
        // 用一张独一无二的图片，避免命中其它用例留下的缓存条目。
        let imageData = Data(repeating: 0x42, count: 4096 + Int.random(in: 0...200))
        let message = userMessageWithImage(conversationID: conversationID, imageData: imageData)

        let decoder = ImageBase64Decoder()
        let before = snapshot(of: decoder)
        let messages = llmMessages(
            from: [message],
            includesImages: false,
            imageDecoder: decoder
        )
        let after = snapshot(of: decoder)

        #expect(messages.count == 1)
        #expect(messages[0].images.isEmpty, "非视觉模型不应收到图片")
        #expect(after.count == before.count, "非视觉模式不应触碰任何图片字节")
    }

    @Test("非视觉模式（includesImages 为 false）不解码工具结果图片")
    func nonVisionModeDoesNotDecodeToolResultImages() {
        let conversationID = UUID()
        let imageData = Data(repeating: 0x33, count: 4096 + Int.random(in: 0...200))
        let (assistant, tool) = assistantAndToolMessagesWithImage(
            conversationID: conversationID,
            imageData: imageData
        )

        let decoder = ImageBase64Decoder()
        let before = snapshot(of: decoder)
        let messages = llmMessages(
            from: [assistant, tool],
            includesImages: false,
            imageDecoder: decoder
        )
        let after = snapshot(of: decoder)

        #expect(messages.count == 2)
        #expect(messages[0].images.isEmpty)
        #expect(messages[1].images.isEmpty)
        #expect(after.count == before.count, "非视觉模式不应触碰任何图片字节")
    }

    @Test("视觉模式（includesImages 为 true）照常解码图片")
    func visionModeStillDecodesImages() {
        let conversationID = UUID()
        let imageData = Data(repeating: 0x42, count: 4096 + Int.random(in: 0...200))
        let message = userMessageWithImage(conversationID: conversationID, imageData: imageData)

        let decoder = ImageBase64Decoder()
        let before = snapshot(of: decoder)
        let messages = llmMessages(
            from: [message],
            includesImages: true,
            imageDecoder: decoder
        )
        let after = snapshot(of: decoder)

        #expect(messages[0].images == [MessageImage(data: imageData, mimeType: "image/png")])
        #expect(after.count == before.count + 1, "视觉模式应处理一次图片字节")
    }

    @Test("工具结果图片在视觉模式下会被处理")
    func visionModeDecodesToolResultImages() {
        let conversationID = UUID()
        let imageData = Data(repeating: 0x33, count: 4096 + Int.random(in: 0...200))
        let (assistant, tool) = assistantAndToolMessagesWithImage(
            conversationID: conversationID,
            imageData: imageData
        )

        let decoder = ImageBase64Decoder()
        let before = snapshot(of: decoder)
        let messages = llmMessages(
            from: [assistant, tool],
            includesImages: true,
            imageDecoder: decoder
        )
        let after = snapshot(of: decoder)

        #expect(messages[1].images == [MessageImage(data: imageData, mimeType: "image/png")])
        #expect(after.count == before.count + 1, "视觉模式应处理一次工具结果图片")
    }

    @Test("非视觉模式的消息内容与视觉模式一致（除图片外）")
    func nonVisionModeKeepsEverythingExceptImages() {
        let conversationID = UUID()
        let imageData = Data(repeating: 0x42, count: 1024)
        let message = userMessageWithImage(conversationID: conversationID, imageData: imageData)

        let withImages = llmMessages(from: [message], includesImages: true)
        let withoutImages = llmMessages(from: [message], includesImages: false)

        #expect(withImages[0].role == withoutImages[0].role)
        #expect(withImages[0].content == withoutImages[0].content)
        #expect(withImages[0].toolCalls == withoutImages[0].toolCalls)
        #expect(withImages[0].toolCallID == withoutImages[0].toolCallID)
        #expect(withImages[0].reasoningContent == withoutImages[0].reasoningContent)
    }

    @Test("默认参数保持原有行为（携带图片）")
    func defaultBehaviourKeepsImages() {
        let conversationID = UUID()
        let imageData = Data(repeating: 0x42, count: 1024)
        let message = userMessageWithImage(conversationID: conversationID, imageData: imageData)

        let messages = llmMessages(from: [message])

        #expect(messages[0].images == [MessageImage(data: imageData, mimeType: "image/png")])
    }

    // MARK: - 离主线程转换

    @MainActor
    @Test("历史转换不在主线程上执行")
    func historyConversionRunsOffMainThread() async {
        let conversationID = UUID()
        // 用一张足够大的图片，让「解码」成为转换里的主要开销，
        // 从而让线程归属可被可靠地观察。
        let imageData = Data(repeating: 0x77, count: 2_000_000)
        let message = userMessageWithImage(conversationID: conversationID, imageData: imageData)

        let decoder = ImageBase64Decoder()
        let before = snapshot(of: decoder)
        _ = await llmMessagesOffMainActor(
            from: [message],
            includesImages: true,
            imageDecoder: decoder
        )
        let after = snapshot(of: decoder)

        #expect(after.count == before.count + 1, "应确实处理了一次图片字节")
        #expect(
            after.mainThreadCount == before.mainThreadCount,
            "历史转换不得在主线程上执行"
        )
    }

    @MainActor
    @Test("离主线程转换的结果与同步转换完全一致")
    func offMainActorConversionMatchesSyncConversion() async {
        let conversationID = UUID()
        let imageData = Data(repeating: 0x55, count: 4096)
        let user = userMessageWithImage(conversationID: conversationID, imageData: imageData)
        let (assistant, tool) = assistantAndToolMessagesWithImage(
            conversationID: conversationID,
            imageData: imageData
        )
        let messages = [assistant, user, tool]

        let sync = llmMessages(from: messages)
        let async = await llmMessagesOffMainActor(from: messages)

        #expect(async.count == sync.count)
        for (left, right) in zip(async, sync) {
            #expect(left.role == right.role)
            #expect(left.content == right.content)
            #expect(left.toolCallID == right.toolCallID)
            #expect(left.images.count == right.images.count)
            for (leftImage, rightImage) in zip(left.images, right.images) {
                #expect(leftImage.data == rightImage.data)
                #expect(leftImage.mimeType == rightImage.mimeType)
            }
        }
    }
}
