import Foundation
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI
import Testing
@testable import PluginMessageRenderer

/// 图片附件解码契约（Issue #1185）。
///
/// 1. 一次求值只解码一遍：`isEmpty` 判定与预览网格共用同一份结果；
/// 2. 跨求值复用解码结果，不重复解码同一份 base64；
/// 3. 载荷变化（流式追加 / 替换）不会读到过期图片；
/// 4. 空串与非法 base64 的丢弃语义与修复前一致。
///
/// 计数一律用**独立**的 `ImageBase64Decoder` 实例经 TaskLocal 注入：
/// `shared` 的计数器与缓存是进程级可变状态，并行用例会互相清空，
/// 断言就会变成随机失败。
@Suite("消息图片解码")
struct MessageImageDecodingTests {

    // MARK: - 辅助

    private func attachments(
        count: Int,
        byte: UInt8 = 0x42,
        size: Int = 1024
    ) -> [MessageImageAttachment] {
        (0..<count).map { index in
            MessageImageAttachment(
                data: Data(repeating: byte &+ UInt8(index), count: size).base64EncodedString(),
                mimeType: "image/png"
            )
        }
    }

    // MARK: - 单次求值

    @Test("一次取用对每张图只进入解码路径一次")
    func singlePassVisitsEachAttachmentOnce() {
        let decoder = ImageBase64Decoder()
        let items = attachments(count: 3)

        let data = MessageImageDecoding.$decoder.withValue(decoder) {
            MessageImageDecoding.imageData(from: items)
        }

        #expect(data.count == 3)
        #expect(decoder.decodeCounter.count == 3)
        #expect(decoder.actualDecodeCounter.count == 3)
    }

    @Test("解码结果与原始字节一致")
    func decodedBytesMatchOriginal() throws {
        let decoder = ImageBase64Decoder()
        let original = Data(repeating: 0x7F, count: 4096)
        let items = [MessageImageAttachment(data: original.base64EncodedString())]

        let data = MessageImageDecoding.$decoder.withValue(decoder) {
            MessageImageDecoding.imageData(from: items)
        }

        #expect(try #require(data.first) == original)
    }

    // MARK: - 跨求值复用

    @Test("重复取用不再解码，只命中缓存")
    func repeatedAccessReusesDecodedBytes() {
        let decoder = ImageBase64Decoder()
        let items = attachments(count: 2)

        MessageImageDecoding.$decoder.withValue(decoder) {
            let first = MessageImageDecoding.imageData(from: items)
            let second = MessageImageDecoding.imageData(from: items)

            #expect(first == second)
            // 两次取用各进入解码路径 2 次，但真正解码只发生在第一次。
            #expect(decoder.decodeCounter.count == 4)
            #expect(decoder.actualDecodeCounter.count == 2)
        }
    }

    @Test("默认走进程级共享缓存")
    func defaultDecoderIsTheSharedCache() {
        #expect(MessageImageDecoding.decoder === ImageBase64Decoder.shared)
    }

    // MARK: - 身份与失效

    @Test("替换载荷后重新解码，不返回旧图片")
    func replacedPayloadIsDecodedAgain() {
        let decoder = ImageBase64Decoder()
        // 两组载荷刻意不相交：缓存按内容寻址，相交的那张本就该命中。
        let before = attachments(count: 2, byte: 0x01)
        let after = attachments(count: 2, byte: 0x11)

        MessageImageDecoding.$decoder.withValue(decoder) {
            let first = MessageImageDecoding.imageData(from: before)
            let second = MessageImageDecoding.imageData(from: after)

            #expect(first != second)
            #expect(second == after.compactMap { Data(base64Encoded: $0.data) })
            #expect(decoder.actualDecodeCounter.count == 4)
        }
    }

    @Test("流式追加只解码新增的那张图")
    func appendedPayloadOnlyDecodesTheNewImage() {
        let decoder = ImageBase64Decoder()
        let first = attachments(count: 1, byte: 0x10)
        let second = attachments(count: 2, byte: 0x10)

        MessageImageDecoding.$decoder.withValue(decoder) {
            let before = MessageImageDecoding.imageData(from: first)
            let after = MessageImageDecoding.imageData(from: second)

            #expect(after.count == 2)
            #expect(after.first == before.first)
            #expect(decoder.actualDecodeCounter.count == 2)
            #expect(decoder.decodeCounter.count == 3)
        }
    }

    // MARK: - 非法载荷

    @Test("空串与非法 base64 被丢弃")
    func invalidAndEmptyPayloadsAreDropped() {
        let decoder = ImageBase64Decoder()
        let valid = Data(repeating: 0x33, count: 512)
        let items = [
            MessageImageAttachment(data: ""),
            MessageImageAttachment(data: valid.base64EncodedString()),
            MessageImageAttachment(data: "not base64 !!!")
        ]

        let data = MessageImageDecoding.$decoder.withValue(decoder) {
            MessageImageDecoding.imageData(from: items)
        }

        #expect(data == [valid])
    }

    @Test("没有附件时不进入解码路径")
    func emptyAttachmentsDoNotDecode() {
        let decoder = ImageBase64Decoder()

        let data = MessageImageDecoding.$decoder.withValue(decoder) {
            MessageImageDecoding.imageData(from: [])
        }

        #expect(data.isEmpty)
        #expect(decoder.decodeCounter.count == 0)
    }
}

/// 四处 body 的解码次数契约（Issue #1185）。
///
/// 修复前：助手正文每次 body 求值解码 **2 遍**，工具结果 **2–3 遍**
/// （空输出分支多一遍）。这里直接求值 body，用独立解码器计数。
@MainActor
@Suite("body 内的图片解码次数", .serialized)
struct MessageImageBodyDecodingTests {

    // MARK: - 辅助

    private func attachments(count: Int) -> [MessageImageAttachment] {
        (0..<count).map { index in
            MessageImageAttachment(
                data: Data(repeating: 0x40 &+ UInt8(index), count: 2048).base64EncodedString(),
                mimeType: "image/png"
            )
        }
    }

    /// 图像生成响应的典型形态：正文为空，只有图片。
    private func message(imageCount: Int) -> Message {
        Message(
            conversationID: UUID(),
            role: .assistant,
            content: "",
            imageAttachments: attachments(count: imageCount)
        )
    }

    private func toolResult(imageCount: Int, content: String) -> MessageToolResult {
        MessageToolResult(content: content, imageAttachments: attachments(count: imageCount))
    }

    // MARK: - 助手正文（V1–V3 / V4 / V5）

    @Test("V1–V3 助手正文每次求值只解码一遍，跨求值不重复解码")
    func legacyAssistantBodyDecodesOnce() {
        let decoder = ImageBase64Decoder()
        let view = AssistantMessageBody(
            capability: ChatGPTAssistantStubCapability(retryableTurnIDs: []),
            stateViewModel: MessageRendererStateViewModel(),
            message: message(imageCount: 2),
            shouldHideAssistantBody: false,
            contentVerbosity: .standard,
            isV1: false
        )

        MessageImageDecoding.$decoder.withValue(decoder) {
            _ = view.body
            #expect(decoder.decodeCounter.count == 2)
            #expect(decoder.actualDecodeCounter.count == 2)

            _ = view.body
            #expect(decoder.decodeCounter.count == 4)
            #expect(decoder.actualDecodeCounter.count == 2)
        }
    }

    @Test("V4 助手正文每次求值只解码一遍，跨求值不重复解码")
    func zcodeAssistantBodyDecodesOnce() {
        let decoder = ImageBase64Decoder()
        let view = ZCodeAssistantMessageView(
            capability: ChatGPTAssistantStubCapability(retryableTurnIDs: []),
            stateViewModel: MessageRendererStateViewModel(),
            message: message(imageCount: 2),
            verbosity: .zcode
        )

        MessageImageDecoding.$decoder.withValue(decoder) {
            _ = view.body
            #expect(decoder.decodeCounter.count == 2)
            #expect(decoder.actualDecodeCounter.count == 2)

            _ = view.body
            #expect(decoder.decodeCounter.count == 4)
            #expect(decoder.actualDecodeCounter.count == 2)
        }
    }

    @Test("V5 助手正文每次求值只解码一遍，跨求值不重复解码")
    func chatGPTAssistantBodyDecodesOnce() {
        let decoder = ImageBase64Decoder()
        let view = ChatGPTAssistantMessageView(
            capability: ChatGPTAssistantStubCapability(retryableTurnIDs: []),
            stateViewModel: MessageRendererStateViewModel(),
            message: message(imageCount: 2),
            verbosity: .chatGPT
        )

        MessageImageDecoding.$decoder.withValue(decoder) {
            _ = view.body
            #expect(decoder.decodeCounter.count == 2)
            #expect(decoder.actualDecodeCounter.count == 2)

            _ = view.body
            #expect(decoder.decodeCounter.count == 4)
            #expect(decoder.actualDecodeCounter.count == 2)
        }
    }

    // MARK: - 工具结果

    @Test("工具结果有正文时每次求值只解码一遍")
    func toolResultWithTextDecodesOnce() {
        let decoder = ImageBase64Decoder()
        let result = toolResult(imageCount: 2, content: "已截图")
        let view = ToolCallResultView(
            result: result,
            isLoading: false,
            visualState: ToolCallResultVisualState(result: result, isLoading: false)
        )

        MessageImageDecoding.$decoder.withValue(decoder) {
            _ = view.body
            #expect(decoder.decodeCounter.count == 2)
            #expect(decoder.actualDecodeCounter.count == 2)

            _ = view.body
            #expect(decoder.decodeCounter.count == 4)
            #expect(decoder.actualDecodeCounter.count == 2)
        }
    }

    @Test("工具结果空输出分支不再多解码一遍")
    func toolResultWithEmptyTextDecodesOnce() {
        let decoder = ImageBase64Decoder()
        let result = toolResult(imageCount: 2, content: "   ")
        let view = ToolCallResultView(
            result: result,
            isLoading: false,
            visualState: ToolCallResultVisualState(result: result, isLoading: false)
        )

        MessageImageDecoding.$decoder.withValue(decoder) {
            _ = view.body
            // 修复前这里是 6（三遍）。
            #expect(decoder.decodeCounter.count == 2)
            #expect(decoder.actualDecodeCounter.count == 2)
        }
    }

    @Test("没有图片的工具结果不进入解码路径")
    func toolResultWithoutImagesDoesNotDecode() {
        let decoder = ImageBase64Decoder()
        let result = toolResult(imageCount: 0, content: "完成")
        let view = ToolCallResultView(
            result: result,
            isLoading: false,
            visualState: ToolCallResultVisualState(result: result, isLoading: false)
        )

        MessageImageDecoding.$decoder.withValue(decoder) {
            _ = view.body
            #expect(decoder.decodeCounter.count == 0)
        }
    }

    @Test("加载中不触碰图片字节")
    func loadingToolResultDoesNotDecode() {
        let decoder = ImageBase64Decoder()
        let result = toolResult(imageCount: 2, content: "")
        let view = ToolCallResultView(
            result: result,
            isLoading: true,
            visualState: ToolCallResultVisualState(result: result, isLoading: true)
        )

        MessageImageDecoding.$decoder.withValue(decoder) {
            _ = view.body
            #expect(decoder.decodeCounter.count == 0)
        }
    }
}