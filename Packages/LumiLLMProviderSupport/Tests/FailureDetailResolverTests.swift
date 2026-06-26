import Foundation
import HttpKit
import LumiCoreKit
import Testing
@testable import LumiLLMProviderSupport

@Suite("LumiLLMFailureDetailResolver")
struct LumiLLMFailureDetailResolverTests {
    @Test func httpErrorUsesRawBodyForSummaryAndTransportDetails() {
        let body = #"{"error":"invalid request"}"#
        let error = HTTPClientError.httpError(statusCode: 400, message: body)
        let detail = LumiLLMFailureDetailResolver.resolve(from: error)

        #expect(detail.httpStatusCode == 400)
        #expect(detail.transportDetails == body)
        #expect(detail.summary.contains("invalid request"))
        #expect(!detail.summary.contains("URL:"))
        #expect(!detail.summary.contains("HTTP 错误"))
        #expect(!detail.summary.contains("HTTP error"))
    }

    @Test func userFacingDescriptionReturnsSummaryOnly() {
        let error = HTTPClientError.httpError(statusCode: 401, message: "invalid_api_key")
        let description = LumiLLMProviderSupportLocalization.userFacingDescription(for: error)

        #expect(description == "invalid_api_key")
        #expect(!description.contains("HTTP"))
    }

    @Test func streamingFailedKeepsSummarySeparateFromTransportMetadata() {
        let message = "provider rejected request"
        let error = LumiLLMProviderSupportError.streamingFailed(message)
        let detail = LumiLLMFailureDetailResolver.resolve(from: error)

        #expect(detail.summary == message)
        #expect(detail.transportDetails == nil)
    }
}
