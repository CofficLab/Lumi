import KernelLumi
import XCTest
@testable import LLMKit

final class ProviderSupportCoverageTests: XCTestCase {

    // MARK: - ProviderHTTPErrorParser

    func testParseOpenAICompatibleDecodesNestedError() {
        let data = Data(#"{"error":{"message":"bad key","type":"invalid_request_error"}}"#.utf8)
        let parsed = ProviderHTTPErrorParser.parseOpenAICompatible(data: data, statusCode: 401)
        XCTAssertEqual(parsed?.message, "bad key")
        XCTAssertEqual(parsed?.statusCode, 401)
        XCTAssertEqual(parsed?.isRetryable, false)
    }

    func testParseOpenAICompatibleFallsBackToGeneric() {
        let data = Data(#"{"message":"plain message"}"#.utf8)
        let parsed = ProviderHTTPErrorParser.parseOpenAICompatible(data: data, statusCode: 500)
        XCTAssertEqual(parsed?.message, "plain message")
        XCTAssertEqual(parsed?.isRetryable, true)
    }

    func testParseAnthropicCompatibleDecodesError() {
        let data = Data(#"{"error":{"message":"overloaded","type":"overloaded_error"}}"#.utf8)
        let parsed = ProviderHTTPErrorParser.parseAnthropicCompatible(data: data, statusCode: 529)
        XCTAssertEqual(parsed?.message, "overloaded")
        XCTAssertEqual(parsed?.isRetryable, true)
    }

    func testParseAnthropicCompatibleFallsBackToGeneric() {
        let data = Data(#"{"error":{"message":"x"}}"#.utf8)
        let parsed = ProviderHTTPErrorParser.parseAnthropicCompatible(data: data, statusCode: 400)
        XCTAssertEqual(parsed?.message, "x")
        XCTAssertEqual(parsed?.isRetryable, false)
    }

    func testParseGenericJSONVariants() {
        XCTAssertEqual(ProviderHTTPErrorParser.parseGenericJSON(data: nil, statusCode: 400), nil)
        XCTAssertEqual(ProviderHTTPErrorParser.parseGenericJSON(data: Data("not json".utf8), statusCode: 400), nil)
        XCTAssertEqual(
            ProviderHTTPErrorParser.parseGenericJSON(data: Data(#"{"other":1}"#.utf8), statusCode: 400)?.message,
            nil
        )
        XCTAssertEqual(
            ProviderHTTPErrorParser.parseGenericJSON(data: Data(#"{"message":"m"}"#.utf8), statusCode: nil)?.message,
            "m"
        )
        XCTAssertEqual(
            ProviderHTTPErrorParser.parseGenericJSON(data: Data(#"{"message":"m"}"#.utf8), statusCode: 429)?.isRetryable,
            true
        )
    }

    // MARK: - ProviderRetryPolicy

    func testRetryPolicyRespectsRetryAfterHeader() {
        let decision = ProviderRetryPolicy.decision(statusCode: 400, retryAfter: 3, attempt: 0, maxAttempts: 3)
        XCTAssertEqual(decision, ProviderRetryDecision(shouldRetry: true, delaySeconds: 3))
    }

    func testRetryPolicyRetryableStatusCodes() {
        XCTAssertEqual(
            ProviderRetryPolicy.decision(statusCode: 429, retryAfter: nil, attempt: 0, maxAttempts: 3).shouldRetry,
            true
        )
        XCTAssertEqual(
            ProviderRetryPolicy.decision(statusCode: 503, retryAfter: nil, attempt: 0, maxAttempts: 3).shouldRetry,
            true
        )
        XCTAssertEqual(
            ProviderRetryPolicy.decision(statusCode: 404, retryAfter: nil, attempt: 0, maxAttempts: 3).shouldRetry,
            false
        )
    }

    func testRetryPolicyStopsAtMaxAttempts() {
        XCTAssertEqual(
            ProviderRetryPolicy.decision(statusCode: 500, retryAfter: nil, attempt: 3, maxAttempts: 3).shouldRetry,
            false
        )
        XCTAssertEqual(
            ProviderRetryPolicy.decision(forNetworkError: URLError(.timedOut), attempt: 1, maxAttempts: 1).shouldRetry,
            false
        )
    }

    func testRetryPolicyNetworkErrors() {
        let retryable: [URLError.Code] = [
            .timedOut, .notConnectedToInternet, .cannotConnectToHost, .networkConnectionLost,
        ]
        for code in retryable {
            XCTAssertEqual(
                ProviderRetryPolicy.decision(forNetworkError: URLError(code), attempt: 0, maxAttempts: 2).shouldRetry,
                true
            )
        }
        XCTAssertEqual(
            ProviderRetryPolicy.decision(forNetworkError: URLError(.badURL), attempt: 0, maxAttempts: 2).shouldRetry,
            false
        )
    }

    // MARK: - AnthropicCompatibleProviderError

    func testAnthropicErrorDescriptions() {
        XCTAssertEqual(AnthropicCompatibleProviderError.noContent.errorDescription, "No content in response")
        XCTAssertEqual(AnthropicCompatibleProviderError.apiError(message: "boom").errorDescription, "boom")
    }

    // MARK: - LLMTransportDetails

    func testTransportDetailsTruncation() {
        let short = "abc"
        XCTAssertEqual(LLMTransportDetails.truncatedBodyForDisplay(short), short)
        let long = String(repeating: "a", count: LLMTransportDetails.maxBodyDisplayCharacters + 10)
        let truncated = LLMTransportDetails.truncatedBodyForDisplay(long)
        XCTAssertTrue(truncated.contains("...[truncated,"))
        XCTAssertEqual(truncated.count, LLMTransportDetails.maxBodyDisplayCharacters + "\n...[truncated, 2010 characters total]".count)
    }

    func testTransportDetailsSplitWithoutSeparator() {
        let split = LLMTransportDetails.split("just a summary")
        XCTAssertEqual(split.summary, "just a summary")
        XCTAssertNil(split.requestDetails)
        XCTAssertFalse(split.hasTransportDetails)
        XCTAssertTrue(LLMTransportDetails.metadata(from: split).isEmpty)
    }

    func testTransportDetailsSplitWithRequestAndResponse() {
        let full = "summary"
            + LLMTransportDetails.summarySeparator
            + "Request Body: x\n\nResponse Status: 200"
        let split = LLMTransportDetails.split(full)
        XCTAssertEqual(split.summary, "summary")
        XCTAssertEqual(split.requestDetails, "Request Body: x")
        XCTAssertEqual(split.responseDetails, "Response Status: 200")
        XCTAssertTrue(split.hasTransportDetails)
        let metadata = LLMTransportDetails.metadata(from: split)
        XCTAssertEqual(metadata[LLMTransportMetadata.requestDetails], "Request Body: x")
        XCTAssertEqual(metadata[LLMTransportMetadata.responseDetails], "Response Status: 200")
    }

    func testTransportDetailsCombinedCopyText() {
        XCTAssertEqual(LLMTransportDetails.combinedCopyText(summary: nil, requestDetails: nil, responseDetails: nil), "")
        let text = LLMTransportDetails.combinedCopyText(summary: "s", requestDetails: "req", responseDetails: "resp")
        XCTAssertTrue(text.contains("--- Request ---\nreq"))
        XCTAssertTrue(text.contains("--- Response ---\nresp"))
    }

    // MARK: - LumiToolNameDeduplication

    func testToolNameDeduplicationPassesUniqueEntries() throws {
        XCTAssertNoThrow(try LumiToolNameDeduplication.validateUnique(entries: [
            LumiToolNameDeduplication.ValidateEntry(name: "a", owner: "A"),
            LumiToolNameDeduplication.ValidateEntry(name: "b", owner: "B"),
        ]))
    }

    func testToolNameDeduplicationThrowsOnDuplicatesSortedByName() throws {
        XCTAssertThrowsError(
            try LumiToolNameDeduplication.validateUnique(entries: [
                LumiToolNameDeduplication.ValidateEntry(name: "z_tool", owner: "P1"),
                LumiToolNameDeduplication.ValidateEntry(name: "a_tool", owner: "P2"),
                LumiToolNameDeduplication.ValidateEntry(name: "z_tool", owner: "P3"),
                LumiToolNameDeduplication.ValidateEntry(name: "a_tool", owner: "P4"),
            ])
        ) { error in
            guard case LumiToolRegistrationError.duplicateNames(let entries) = error else {
                return XCTFail("expected duplicateNames")
            }
            XCTAssertEqual(entries.map(\.name), ["a_tool", "z_tool"])
            XCTAssertEqual(entries[0].owners, ["P2", "P4"])
            XCTAssertEqual(entries[1].owners, ["P1", "P3"])
        }
    }
}
