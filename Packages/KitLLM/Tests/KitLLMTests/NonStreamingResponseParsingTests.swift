import Foundation
import KitAgentTool
import Testing
@testable import KitLLM

/// 非流式响应解析的契约（Issue #1270）。
///
/// 三条核心要求：
/// 1. **成功响应只被完整解析一次** —— 此前是「错误信封预解析 + 正式解析
///    + usage 重解析」三次；
/// 2. **错误信封仍能被正确识别** —— 错误语义不变；
/// 3. **响应解析不在主线程上同步执行**。
// - Important: 标 `.serialized`。
//   解析计数器是进程内共享的静态状态，并行运行的用例会互相干扰计数，
//   导致「只解析一次」的断言随机失败。
@Suite("非流式响应解析", .serialized)
struct NonStreamingResponseParsingTests {

    // MARK: - 辅助

    private func adapter() -> OpenAICompatibleProviderAdapter {
        OpenAICompatibleProviderAdapter(
            configuration: OpenAICompatibleProviderConfiguration(baseURL: "https://example.com")
        )
    }

    /// 成功响应（含 usage）。
    private func successPayload() -> [String: Any] {
        [
            "id": "chatcmpl-1",
            "choices": [[
                "index": 0,
                "message": ["role": "assistant", "content": "你好"],
                "finish_reason": "stop"
            ]],
            "usage": ["prompt_tokens": 10, "completion_tokens": 5]
        ]
    }

    /// 错误信封。
    private func errorPayload() -> [String: Any] {
        ["error": ["message": "配额已用尽"]]
    }

    private func data(_ payload: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: payload)
    }

    // MARK: - 只解析一次

    @Test("成功响应只被完整解析一次")
    func successfulResponseIsParsedOnce() throws {
        OpenAICompatibleProviderAdapter.responseParseCounter.reset()
        let payload = try data(successPayload())

        _ = try adapter().parseResponse(data: payload)

        #expect(
            OpenAICompatibleProviderAdapter.responseParseCounter.count == 1,
            "成功响应应只被解析一次"
        )
    }

    @Test("带工具调用与思考的成功响应同样只解析一次")
    func richSuccessfulResponseIsParsedOnce() throws {
        OpenAICompatibleProviderAdapter.responseParseCounter.reset()
        let payload = try data([
            "id": "chatcmpl-2",
            "choices": [[
                "index": 0,
                "message": [
                    "role": "assistant",
                    "content": "调用工具",
                    "reasoning_content": "思考中",
                    "tool_calls": [[
                        "id": "call-1",
                        "type": "function",
                        "function": ["name": "read_file", "arguments": "{}"]
                    ]]
                ],
                "finish_reason": "tool_calls"
            ]],
            "usage": ["prompt_tokens": 20, "completion_tokens": 8]
        ])

        _ = try adapter().parseResponse(data: payload)

        #expect(OpenAICompatibleProviderAdapter.responseParseCounter.count == 1)
    }

    @Test("错误信封被正确识别")
    func errorEnvelopeIsDetected() throws {
        let payload = try data(errorPayload())

        #expect(throws: OpenAICompatibleProviderError.self) {
            _ = try adapter().parseResponse(data: payload)
        }
    }

    @Test("错误信封的错误消息被保留")
    func errorEnvelopeKeepsMessage() throws {
        let payload = try data(errorPayload())

        do {
            _ = try adapter().parseResponse(data: payload)
            Issue.record("应抛出供应商错误")
        } catch let error as OpenAICompatibleProviderError {
            guard case let .apiError(message) = error else {
                Issue.record("应为 apiError，实际: \(error)")
                return
            }
            #expect(message == "配额已用尽")
        }
    }

    @Test("非错误但畸形的响应仍抛出解码错误")
    func malformedResponseThrowsDecodingError() throws {
        let payload = try data(["unexpected": "shape"])

        #expect(throws: (any Error).self) {
            _ = try adapter().parseResponse(data: payload)
        }
    }

    // MARK: - usage 随响应带出

    @Test("usage 随响应解析一并带出")
    func usageComesWithParsedResponse() throws {
        let payload = try data(successPayload())

        let parsed = try adapter().parseResponse(data: payload)

        #expect(parsed.tokenUsage.input == 10)
        #expect(parsed.tokenUsage.output == 5)
    }

    @Test("响应没有 usage 时计数为 nil")
    func missingUsageYieldsNil() throws {
        var payload = successPayload()
        payload.removeValue(forKey: "usage")
        let data = try data(payload)

        let parsed = try adapter().parseResponse(data: data)

        #expect(parsed.tokenUsage.input == nil)
        #expect(parsed.tokenUsage.output == nil)
    }

    @Test("解析结果与修复前一致")
    func parsedFieldsAreUnchanged() throws {
        let payload = try data(successPayload())

        let parsed = try adapter().parseResponse(data: payload)

        #expect(parsed.content == "你好")
        #expect(parsed.responseID == "chatcmpl-1")
        #expect(parsed.stopReason == "stop")
        #expect(parsed.toolCalls == nil)
        #expect(parsed.reasoningContent == nil)
    }

    @Test("工具名按 reverseMap 还原")
    func toolNamesAreRestored() throws {
        let payload = try data([
            "id": "chatcmpl-3",
            "choices": [[
                "index": 0,
                "message": [
                    "role": "assistant",
                    "content": "",
                    "tool_calls": [[
                        "id": "call-1",
                        "type": "function",
                        "function": ["name": "read_file", "arguments": "{}"]
                    ]]
                ],
                "finish_reason": "tool_calls"
            ]]
        ])

        let parsed = try adapter().parseResponse(
            data: payload,
            reverseMap: ["read_file": "app.read_file"]
        )

        #expect(parsed.toolCalls?.first?.name == "app.read_file")
    }

    // MARK: - 生成图片

    @Test("内联生成图片被正确解码")
    func inlineGeneratedImageIsDecoded() throws {
        let expected = Data(repeating: 0x42, count: 128)
        let payload = try data([
            "id": "chatcmpl-4",
            "choices": [[
                "index": 0,
                "message": [
                    "role": "assistant",
                    "content": "",
                    "images": [[
                        "type": "image_url",
                        "image_url": ["url": "data:image/png;base64,\(expected.base64EncodedString())"]
                    ]]
                ],
                "finish_reason": "stop"
            ]]
        ])

        let parsed = try adapter().parseResponse(data: payload)

        #expect(parsed.images?.count == 1)
        #expect(parsed.images?.first?.data == expected)
        #expect(parsed.images?.first?.mimeType == "image/png")
    }

    @Test("非 data URL 的图片被跳过")
    func nonDataURLImageIsSkipped() throws {
        let payload = try data([
            "id": "chatcmpl-5",
            "choices": [[
                "index": 0,
                "message": [
                    "role": "assistant",
                    "content": "",
                    "images": [[
                        "type": "image_url",
                        "image_url": ["url": "https://example.com/a.png"]
                    ]]
                ],
                "finish_reason": "stop"
            ]]
        ])

        let parsed = try adapter().parseResponse(data: payload)

        #expect(parsed.images?.isEmpty == true)
    }
}
