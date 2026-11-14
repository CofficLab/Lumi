import Foundation
import KitLLM
import ProviderMessage
import Testing
@testable import ProviderAgentLoop

/// ProviderAgentLoop 侧的历史图片解码契约（Issue #1268）。
///
/// 与 `PluginAgentLoop` 侧的同名契约互补：两个包各自持有一份
/// `llmMessages` 实现，因此两边的行为都要单独锁定。
@Suite("ProviderAgentLoop 历史图片解码")
struct ProviderAgentLoopHistoryImageDecodingTests {

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

    @Test("非视觉模式不解码用户图片附件")
    func nonVisionModeDoesNotDecodeUserImages() {
        let conversationID = UUID()
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

        #expect(messages[0].images.isEmpty, "非视觉模型不应收到图片")
        #expect(after.count == before.count, "非视觉模式不应触碰任何图片字节")
    }

    @Test("视觉模式照常解码图片")
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

    @MainActor
    @Test("历史转换不在主线程上执行")
    func historyConversionRunsOffMainThread() async {
        let conversationID = UUID()
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
        let message = userMessageWithImage(conversationID: conversationID, imageData: imageData)

        let sync = llmMessages(from: [message])
        let async = await llmMessagesOffMainActor(from: [message])

        #expect(async.count == sync.count)
        #expect(async[0].role == sync[0].role)
        #expect(async[0].content == sync[0].content)
        #expect(async[0].images.count == sync[0].images.count)
        for (leftImage, rightImage) in zip(async[0].images, sync[0].images) {
            #expect(leftImage.data == rightImage.data)
            #expect(leftImage.mimeType == rightImage.mimeType)
        }
    }
}
