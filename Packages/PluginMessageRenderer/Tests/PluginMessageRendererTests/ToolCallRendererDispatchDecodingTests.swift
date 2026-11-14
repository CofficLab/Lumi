import Foundation
import KitAgentTool
import ProviderMessage
import Testing
@testable import PluginMessageRenderer

/// 渲染器分发的图片解码契约（Issue #1274）。
///
/// 核心要求：
/// 1. **匹配阶段不解码任何图片字节** —— 没有任何 `canRender` 会读结果图片；
/// 2. 渲染阶段拿到的图片内容与修复前完全一致；
/// 3. 重复访问走缓存，不重复解码。
@Suite("渲染器分发的图片解码")
struct ToolCallRendererDispatchDecodingTests {

    // MARK: - 辅助

    /// 构造一条带图片结果的工具调用。
    private func toolCallWithImages(
        imageCount: Int = 2,
        byte: UInt8 = 0x42,
        size: Int = 2048
    ) -> MessageToolCall {
        var attachments: [MessageImageAttachment] = []
        for _ in 0..<imageCount {
            attachments.append(
                MessageImageAttachment(
                    data: Data(repeating: byte, count: size).base64EncodedString(),
                    mimeType: "image/png"
                )
            )
        }
        return MessageToolCall(
            id: "call-1",
            name: "screenshot",
            arguments: "{}",
            result: MessageToolResult(content: "已截图", imageAttachments: attachments)
        )
    }

    /// 读取「真正解码」的次数（缓存命中不计入）。
    private func actualDecodeCount() -> Int {
        ImageBase64Decoder.shared.actualDecodeCounter.count
    }

    /// 读取「进入解码路径」的次数（含缓存命中）。
    private func decodePathCount() -> Int {
        ImageBase64Decoder.shared.decodeCounter.count
    }

    // MARK: - 匹配阶段零解码

    @Test("匹配用桥接不解码任何图片字节")
    func matchingBridgeDoesNotDecodeImages() {
        ImageBase64Decoder.shared.removeAll()
        ImageBase64Decoder.shared.decodeCounter.reset()
        ImageBase64Decoder.shared.actualDecodeCounter.reset()
        let toolCall = toolCallWithImages()

        let beforeDecode = decodePathCount()
        let beforeActual = actualDecodeCount()
        let matching = toolCall.agentToolCallForMatching
        let afterDecode = decodePathCount()
        let afterActual = actualDecodeCount()

        #expect(matching.result?.images.isEmpty == true)
        #expect(afterDecode == beforeDecode, "匹配阶段不得触碰图片字节")
        #expect(afterActual == beforeActual, "匹配阶段不得解码图片字节")
    }

    @Test("匹配用桥接保留了匹配所需的全部信息")
    func matchingBridgeKeepsMatchingInformation() {
        let toolCall = MessageToolCall(
            id: "call-1",
            name: "screenshot",
            arguments: #"{"path":"/tmp/a"}"#,
            result: MessageToolResult(
                content: "已截图",
                duration: 1.5,
                isError: false,
                imageAttachments: [
                    MessageImageAttachment(
                        data: Data(repeating: 0x01, count: 64).base64EncodedString(),
                        mimeType: "image/png"
                    )
                ],
                awaitingUserResponse: true
            ),
            displayDescription: "截图",
            authorizationState: "userApproved"
        )

        let matching = toolCall.agentToolCallForMatching

        #expect(matching.id == "call-1")
        #expect(matching.name == "screenshot")
        #expect(matching.arguments == #"{"path":"/tmp/a"}"#)
        #expect(matching.authorizationState == .userApproved)
        #expect(matching.result?.content == "已截图")
        #expect(matching.result?.duration == 1.5)
        #expect(matching.result?.isError == false)
        #expect(matching.result?.awaitingUserResponse == true)
        #expect(matching.displayDescription == "截图")
    }

    @Test("匹配用桥接与完整桥接在匹配维度上完全一致")
    func matchingBridgeMatchesFullBridgeOnMatchingDimensions() {
        let toolCall = MessageToolCall(
            id: "call-1",
            name: "screenshot",
            arguments: "{}",
            result: MessageToolResult(content: "已截图", isError: true),
            authorizationState: "pendingAuthorization"
        )

        let matching = toolCall.agentToolCallForMatching
        let full = toolCall.agentToolCall

        #expect(matching.id == full.id)
        #expect(matching.name == full.name)
        #expect(matching.arguments == full.arguments)
        #expect(matching.authorizationState == full.authorizationState)
        #expect(matching.result?.content == full.result?.content)
        #expect(matching.result?.isError == full.result?.isError)
        #expect(matching.displayDescription == full.displayDescription)
    }

    @Test("匹配用桥接在授权状态缺失时回退为待授权")
    func matchingBridgeFallsBackToPendingAuthorization() {
        let toolCall = MessageToolCall(
            id: "call-1",
            name: "screenshot",
            arguments: "{}",
            authorizationState: nil
        )

        #expect(toolCall.agentToolCallForMatching.authorizationState == .pendingAuthorization)
    }

    @Test("匹配用桥接在没有结果时也能构造")
    func matchingBridgeHandlesMissingResult() {
        let toolCall = MessageToolCall(id: "call-1", name: "screenshot", arguments: "{}")

        let matching = toolCall.agentToolCallForMatching

        #expect(matching.result == nil)
    }

    // MARK: - 渲染阶段内容不变

    @Test("完整桥接解码出的图片与原始字节一致")
    func fullBridgeDecodesImagesCorrectly() throws {
        ImageBase64Decoder.shared.removeAll()
        ImageBase64Decoder.shared.decodeCounter.reset()
        ImageBase64Decoder.shared.actualDecodeCounter.reset()
        let expected = Data(repeating: 0x42, count: 2048)
        let toolCall = toolCallWithImages(imageCount: 1)

        let full = toolCall.agentToolCall

        let images = try #require(full.result?.images)
        #expect(images.count == 1)
        #expect(images[0].data == expected)
        #expect(images[0].mimeType == "image/png")
    }

    @Test("完整桥接保留全部图片")
    func fullBridgeKeepsAllImages() throws {
        ImageBase64Decoder.shared.removeAll()
        ImageBase64Decoder.shared.decodeCounter.reset()
        ImageBase64Decoder.shared.actualDecodeCounter.reset()
        let toolCall = toolCallWithImages(imageCount: 3)

        let full = toolCall.agentToolCall

        let images = try #require(full.result?.images)
        #expect(images.count == 3)
    }

    @Test("非法 base64 的图片被跳过而不是让整个结果失败")
    func invalidBase64ImageIsSkipped() throws {
        ImageBase64Decoder.shared.removeAll()
        ImageBase64Decoder.shared.decodeCounter.reset()
        ImageBase64Decoder.shared.actualDecodeCounter.reset()
        let toolCall = MessageToolCall(
            id: "call-1",
            name: "screenshot",
            arguments: "{}",
            result: MessageToolResult(
                content: "已截图",
                imageAttachments: [
                    MessageImageAttachment(data: "!!!not base64!!!", mimeType: "image/png")
                ]
            )
        )

        let full = toolCall.agentToolCall

        #expect(full.result?.content == "已截图")
        #expect(full.result?.images.isEmpty == true)
    }

    // MARK: - 缓存生效

    @Test("重复访问完整桥接不会重复解码")
    func repeatedFullBridgeUsesCache() {
        ImageBase64Decoder.shared.removeAll()
        ImageBase64Decoder.shared.decodeCounter.reset()
        ImageBase64Decoder.shared.actualDecodeCounter.reset()
        let toolCall = toolCallWithImages(imageCount: 2)

        // 首次：真正解码一次（两张图片内容相同，第二次进缓存）。
        _ = toolCall.agentToolCall
        let afterFirst = actualDecodeCount()
        #expect(afterFirst == 1, "首次应真正解码一次")

        // 再次：命中缓存，不再解码。
        _ = toolCall.agentToolCall
        let afterSecond = actualDecodeCount()
        #expect(afterSecond == afterFirst, "重复访问应命中解码缓存，不重复解码")
    }

    @Test("完整桥接的重复访问产出完全相同的结果")
    func repeatedFullBridgeProducesSameResult() throws {
        ImageBase64Decoder.shared.removeAll()
        ImageBase64Decoder.shared.decodeCounter.reset()
        ImageBase64Decoder.shared.actualDecodeCounter.reset()
        let toolCall = toolCallWithImages(imageCount: 2)

        let first = toolCall.agentToolCall
        let second = toolCall.agentToolCall

        let firstImages = try #require(first.result?.images)
        let secondImages = try #require(second.result?.images)
        #expect(firstImages.count == secondImages.count)
        for (left, right) in zip(firstImages, secondImages) {
            #expect(left.data == right.data)
            #expect(left.mimeType == right.mimeType)
        }
    }
}
