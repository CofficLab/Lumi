import XCTest
@testable import ProviderLLMVendors

final class ProviderLLMTests: XCTestCase {
    func testDefaultProviderIsExplicitlyUnavailable() async {
        do {
            _ = try await DefaultLLMProviding().complete(
                LLMRequest(conversationID: UUID(), messages: [])
            )
            XCTFail("expected not configured")
        } catch let error as LLMProviderError {
            XCTAssertEqual(error, .notConfigured)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testAnthropicToolArgumentsStayWithTheirContentBlock() async throws {
        let adapter = AnthropicCompatibleProviderAdapter(
            configuration: AnthropicCompatibleProviderConfiguration(baseURL: "https://example.com")
        )
        let accumulator = StreamingAccumulator()

        for (index, tool) in [(1, "first"), (2, "second"), (3, "third")] {
            let start = try XCTUnwrap(try adapter.parseStreamChunk(data: anthropicEvent(
                type: "content_block_start",
                payload: [
                    "type": "content_block_start",
                    "index": index,
                    "content_block": [
                        "type": "tool_use",
                        "id": "toolu_\(index)",
                        "name": tool,
                        "input": [:]
                    ]
                ]
            )))
            XCTAssertEqual(start.toolCallIndex, index)
            _ = await accumulator.consume(start) { _ in }

            let delta = try XCTUnwrap(try adapter.parseStreamChunk(data: anthropicEvent(
                type: "content_block_delta",
                payload: [
                    "type": "content_block_delta",
                    "index": index,
                    "delta": ["type": "input_json_delta", "partial_json": "{\"value\":\"\(tool)\"}"]
                ]
            )))
            XCTAssertEqual(delta.toolCallIndex, index)
            _ = await accumulator.consume(delta) { _ in }
        }

        let response = try await accumulator.finish(model: "test")
        XCTAssertEqual(response.toolCalls?.map(\.name), ["first", "second", "third"])
        XCTAssertEqual(response.toolCalls?.map(\.arguments), [
            "{\"value\":\"first\"}",
            "{\"value\":\"second\"}",
            "{\"value\":\"third\"}"
        ])
    }

    func testRetryPolicyClassifiesTransientErrors() {
        let network = ProviderRetryPolicy.decision(
            forNetworkError: NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost),
            attempt: 1,
            maxAttempts: 3
        )
        XCTAssertTrue(network.shouldRetry)

        let unauthorized = ProviderRetryPolicy.decision(
            statusCode: 401,
            retryAfter: nil,
            attempt: 1,
            maxAttempts: 3
        )
        XCTAssertFalse(unauthorized.shouldRetry)
    }

    private func anthropicEvent(type: String, payload: [String: Any]) -> Data {
        let json = try! JSONSerialization.data(withJSONObject: payload)
        return Data("event: \(type)\ndata: \(String(decoding: json, as: UTF8.self))\n\n".utf8)
    }
}
