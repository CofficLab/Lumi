import Foundation
import os
import Testing
@testable import KitLLM

/// Responses 协议必须真正发送图片输入（issue #288）。
///
/// ## 为什么要有这条测试
///
/// 自定义 Responses 模型可以声明 `supportsVision`，但共享的 Responses
/// 序列化只读 role/content，图片附件被静默丢弃——模型声明了视觉能力，
/// 请求里却一个字节都没有。
@MainActor
@Suite("Responses 协议的图片输入（#288）")
struct ResponsesVisionTests {

    /// 捕获请求体的网络桩。
    private final class CapturingNetworkStub: LLMNetworkProviding, @unchecked Sendable {
        let payload: Data
        private let capturedBody = OSAllocatedUnfairLock<Data?>(initialState: nil)

        init(payload: Data) {
            self.payload = payload
        }

        func send(request: URLRequest, body: Data) async throws -> (Data, URLResponse) {
            capturedBody.withLock { $0 = body }
            let url = request.url ?? URL(string: "https://example.invalid")!
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (payload, response)
        }

        func stream(
            request: URLRequest,
            body: Data,
            onEvent: @Sendable @escaping (Data) async -> Bool
        ) async throws {}

        func capturedBodyValue() -> Data? {
            capturedBody.withLock { $0 }
        }
    }

    /// 只实现 Responses 端点的供应商替身。
    private final class ResponsesOnlyProvider: VendorLLMProvider {
        override var responsesEndpointURL: String { "https://example.invalid/v1/responses" }
        override func resolveAPIKey() throws -> String { "sk-test-responses" }
    }

    private static let responsePayload = """
    {
      "id": "resp_vision",
      "object": "response",
      "status": "completed",
      "output": [{
        "type": "message",
        "role": "assistant",
        "content": [{"type": "output_text", "text": "ok", "annotations": []}]
      }]
    }
    """

    private func makeProvider() -> (ResponsesOnlyProvider, CapturingNetworkStub) {
        let network = CapturingNetworkStub(payload: Data(Self.responsePayload.utf8))
        let service = VendorAPIService(networkProvider: network, maxAttempts: 1)
        let provider = ResponsesOnlyProvider(
            info: LLMProviderInfo(
                id: "responses-vision",
                displayName: "Responses Vision",
                defaultModel: "test-model",
                models: [],
                isLocal: true,
                apiFormat: .responses
            ),
            apiService: service
        )
        return (provider, network)
    }

    private func capturedInput(from network: CapturingNetworkStub) throws -> [[String: Any]] {
        let body = try #require(network.capturedBodyValue())
        let object = try #require(
            try JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        return try #require(object["input"] as? [[String: Any]])
    }

    @Test("带图用户消息编码为 input_text + input_image")
    func userImageEncodedAsResponsesParts() async throws {
        let (provider, network) = makeProvider()
        let imageBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x01, 0x02])

        _ = try await provider.complete(
            LLMRequest(
                messages: [
                    LLMMessage(
                        role: .user,
                        content: "这张图里是什么？",
                        images: [MessageImage(data: imageBytes, mimeType: "image/png")]
                    )
                ],
                model: "test-model"
            )
        )

        let input = try capturedInput(from: network)
        let content = try #require(input[0]["content"] as? [[String: Any]])
        #expect(content.count == 2, "应有 text + image 两个内容块，实际 \(content)")
        #expect(content[0]["type"] as? String == "input_text")
        #expect(content[0]["text"] as? String == "这张图里是什么？")
        #expect(content[1]["type"] as? String == "input_image")
        let dataURL = try #require(content[1]["image_url"] as? String)
        #expect(dataURL.hasPrefix("data:image/png;base64,"))
        #expect(
            dataURL.contains(imageBytes.base64EncodedString()),
            "data URI 必须携带图片本身的 base64"
        )
    }

    @Test("无图消息保持纯字符串内容")
    func messageWithoutImageKeepsStringContent() async throws {
        let (provider, network) = makeProvider()

        _ = try await provider.complete(
            LLMRequest(messages: [LLMMessage(role: .user, content: "plain hi")], model: "test-model")
        )

        let input = try capturedInput(from: network)
        #expect(input[0]["content"] as? String == "plain hi")
    }

    @Test("纯图消息不产生空文本块")
    func imageOnlyMessageOmitsEmptyTextPart() async throws {
        let (provider, network) = makeProvider()
        let imageBytes = Data([0xFF, 0xD8, 0xFF])

        _ = try await provider.complete(
            LLMRequest(
                messages: [
                    LLMMessage(
                        role: .user,
                        content: "",
                        images: [MessageImage(data: imageBytes, mimeType: "image/jpeg")]
                    )
                ],
                model: "test-model"
            )
        )

        let input = try capturedInput(from: network)
        let content = try #require(input[0]["content"] as? [[String: Any]])
        #expect(content.count == 1, "不应有空 input_text 块，实际 \(content)")
        #expect(content[0]["type"] as? String == "input_image")
    }
}
