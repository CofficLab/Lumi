import Foundation
import Testing
@testable import KitLLM

/// OpenRouter 图像生成模型的图片载荷必须被保留。
///
/// ## 为什么要有这条测试
///
/// OpenRouter 暴露 `bytedance-seed/seedream-4.5`，模型选择器也明确把它
/// 归到图像模型分组——这是用户可选的生产路径。但 OpenAI 兼容的响应路径
/// 没有 `message.images` / `delta.images` 的表示，生成的图片被直接丢弃。
///
/// 结果是：一次合法的「只生成图片」的响应变成空回复，走空响应失败路径，
/// 用户看不到生成的图片。
@Suite("OpenRouter 图像响应")
struct OpenRouterImageResponseTests {

    /// 一张 1x1 的 PNG（base64）。
    private static let pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

    private func adapter() -> OpenAICompatibleProviderAdapter {
        OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(
                baseURL: "https://example.invalid/v1/chat/completions"
            )
        )
    }

    private func sse(_ payload: String) -> Data {
        Data("data: \(payload)\n\n".utf8)
    }

    // MARK: - 非流式

    @Test("非流式的 message.images 被解码")
    func nonStreamingImagesAreDecoded() throws {
        let payload = Data("""
        {"choices":[{"message":{"role":"assistant","content":null,"images":\
        [{"type":"image_url","image_url":{"url":"data:image/png;base64,\(Self.pngBase64)"}}]}}]}
        """.utf8)

        let parsed = try adapter().parseResponse(data: payload)

        let image = try #require(parsed.images?.first, "生成的图片被丢弃了")
        #expect(image.mimeType == "image/png")
        #expect(image.data == Data(base64Encoded: Self.pngBase64))
    }

    @Test("非流式的图片 mime 类型从 data URL 解析")
    func nonStreamingImageMimeTypeParsed() throws {
        let payload = Data("""
        {"choices":[{"message":{"images":\
        [{"type":"image_url","image_url":{"url":"data:image/jpeg;base64,\(Self.pngBase64)"}}]}}]}
        """.utf8)

        let parsed = try adapter().parseResponse(data: payload)

        #expect(parsed.images?.first?.mimeType == "image/jpeg")
    }

    @Test("非 data URL 的图片被跳过而不是崩溃")
    func nonDataURLImagesAreSkipped() throws {
        let payload = Data("""
        {"choices":[{"message":{"content":"hi","images":\
        [{"type":"image_url","image_url":{"url":"https://example.com/a.png"}}]}}]}
        """.utf8)

        let parsed = try adapter().parseResponse(data: payload)

        #expect(parsed.content == "hi")
        #expect(parsed.images?.isEmpty ?? true)
    }

    @Test("没有图片时图片列表为空")
    func noImagesYieldsEmptyList() throws {
        let payload = Data(#"{"choices":[{"message":{"content":"hello"}}]}"#.utf8)

        let parsed = try adapter().parseResponse(data: payload)

        #expect(parsed.content == "hello")
        #expect(parsed.images?.isEmpty ?? true)
    }

    // MARK: - 流式

    @Test("流式的 delta.images 产出图片 chunk")
    func streamingImagesProduceChunk() throws {
        let payload = """
        {"choices":[{"delta":{"images":\
        [{"type":"image_url","image_url":{"url":"data:image/png;base64,\(Self.pngBase64)"}}]}}]}
        """

        let chunks = try adapter().parseStreamChunks(data: sse(payload))

        let image = try #require(chunks.first { $0.images?.isEmpty == false }, "流式图片未产出 chunk")
        #expect(image.images?.first?.mimeType == "image/png")
        #expect(image.images?.first?.data == Data(base64Encoded: Self.pngBase64))
    }
}
