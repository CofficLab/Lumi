import Testing
import Foundation
@testable import LLMKit

@Suite("LLMServiceError Tests")
struct LLMServiceErrorTests {

    // MARK: - errorDescription

    @Test("apiKeyEmpty 描述")
    func apiKeyEmptyDescription() {
        let error = LLMServiceError.apiKeyEmpty
        #expect(error.errorDescription == "API Key cannot be empty")
    }

    @Test("modelEmpty 描述")
    func modelEmptyDescription() {
        let error = LLMServiceError.modelEmpty
        #expect(error.errorDescription == "Model name cannot be empty")
    }

    @Test("providerIdEmpty 描述")
    func providerIdEmptyDescription() {
        let error = LLMServiceError.providerIdEmpty
        #expect(error.errorDescription == "Provider ID cannot be empty")
    }

    @Test("temperatureOutOfRange 描述包含具体值")
    func temperatureOutOfRangeDescription() {
        let error = LLMServiceError.temperatureOutOfRange(3.14)
        #expect(error.errorDescription?.contains("3.14") == true)
    }

    @Test("maxTokensInvalid 描述包含具体值")
    func maxTokensInvalidDescription() {
        let error = LLMServiceError.maxTokensInvalid(-1)
        #expect(error.errorDescription?.contains("-1") == true)
    }

    @Test("providerNotFound 描述包含 providerId")
    func providerNotFoundDescription() {
        let error = LLMServiceError.providerNotFound(providerId: "openai")
        #expect(error.errorDescription == "Provider not found: openai")
    }

    @Test("invalidBaseURL 描述包含 URL")
    func invalidBaseURLDescription() {
        let error = LLMServiceError.invalidBaseURL("not a url")
        #expect(error.errorDescription == "Invalid Base URL: not a url")
    }

    @Test("cancelled 描述")
    func cancelledDescription() {
        let error = LLMServiceError.cancelled
        #expect(error.errorDescription == "Cancelled")
    }

    @Test("requestFailed 描述透传消息")
    func requestFailedDescription() {
        let error = LLMServiceError.requestFailed("timeout")
        #expect(error.errorDescription == "timeout")
    }

    // MARK: - Equatable

    @Test("相同枚举值相等")
    func equalitySame() {
        #expect(LLMServiceError.apiKeyEmpty == LLMServiceError.apiKeyEmpty)
        #expect(LLMServiceError.cancelled == LLMServiceError.cancelled)
    }

    @Test("不同枚举值不等")
    func equalityDifferent() {
        #expect(LLMServiceError.apiKeyEmpty != LLMServiceError.modelEmpty)
    }

    @Test("带关联值的相等")
    func equalityAssociatedValues() {
        #expect(
            LLMServiceError.providerNotFound(providerId: "a")
            == LLMServiceError.providerNotFound(providerId: "a")
        )
    }

    @Test("带关联值的不等")
    func equalityDifferentAssociatedValues() {
        #expect(
            LLMServiceError.providerNotFound(providerId: "a")
            != LLMServiceError.providerNotFound(providerId: "b")
        )
    }

    @Test("requestFailed 关联值相等")
    func equalityRequestFailed() {
        #expect(
            LLMServiceError.requestFailed("err")
            == LLMServiceError.requestFailed("err")
        )
    }
}
