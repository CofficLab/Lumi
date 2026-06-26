import Foundation
import HttpKit
import LumiCoreKit
import Testing
@testable import LumiLLMProviderSupport

@Suite("LumiLLMProviderSupportError", .serialized)
struct LumiLLMProviderSupportErrorTests {
    @Test func localizedMissingAPIKeyIncludesProviderName() {
        let error = LumiLLMProviderSupportError.missingAPIKey("ZhiPu")
        let description = error.localizedDescription(locale: .current)

        #expect(description.contains("ZhiPu"))
        #expect(description.contains("API Key"))
    }

    @Test func userFacingDescriptionIncludesResponseExcerpt() {
        let error = HTTPClientError.httpError(statusCode: 401, message: "invalid_api_key")
        let description = LumiLLMProviderSupportLocalization.userFacingDescription(for: error)

        #expect(description.contains("invalid_api_key"))
        #expect(!description.contains("HTTP 错误"))
    }

    @Test func userFacingDescriptionPassesThroughStreamingFailedMessage() {
        let error = LumiLLMProviderSupportError.streamingFailed("provider rejected request")
        let description = LumiLLMProviderSupportLocalization.userFacingDescription(for: error)

        #expect(description == "provider rejected request")
    }

    @Test func allEndpointsFailedIsLocalizedForZhHans() {
        let error = LumiLLMProviderSupportError.allEndpointsFailed
        let description = error.localizedDescription(locale: Locale(identifier: "zh-Hans"))

        #expect(description == "所有供应商接口均请求失败。")
    }

    @Test func missingAPIKeyIsNotRetryable() {
        let error = LumiLLMProviderSupportError.missingAPIKey("Test")
        #expect(error.llmErrorDisposition.isRetryable == false)
    }

    @Test func streamingFailedIsRetryable() {
        let error = LumiLLMProviderSupportError.streamingFailed("timeout")
        #expect(error.llmErrorDisposition.isRetryable == true)
    }
}
