import LumiKernel
import HttpKit
import XCTest
@testable import LLMKit

final class ProviderErrorSupportTests: XCTestCase {
    func testHTTPErrorMessagePreservesStatusCodeAndBody() {
        let request = LumiLLMRequest(messages: [], model: "test-model")
        let body = #"{"error":"invalid request"}"#

        let message = LumiLLMProviderErrorSupport.makeErrorMessage(
            providerID: "test-provider",
            conversationID: UUID(),
            request: request,
            error: HTTPClientError.httpError(statusCode: 422, message: body),
            disposition: .nonRetryable,
            renderKind: nil
        )

        XCTAssertEqual(message.httpStatusCode, 422)
        XCTAssertEqual(message.httpBody, body)
    }

    func testMissingAPIKeyUsesGenericRenderKindWhenProviderDoesNotProvideOne() {
        let conversationID = UUID()
        let request = LumiLLMRequest(messages: [], model: "test-model")

        let message = LumiLLMProviderErrorSupport.makeErrorMessage(
            providerID: "test-provider",
            conversationID: conversationID,
            request: request,
            error: LumiLLMProviderSupportError.missingAPIKey("Test Provider"),
            disposition: .nonRetryable,
            renderKind: nil
        )

        XCTAssertEqual(message.renderKind, LumiLLMProviderAPIKeyMessage.renderKind)
        XCTAssertTrue(LumiLLMProviderAPIKeyMessage.isMissingAPIKeyMessage(message))
    }

    func testMissingAPIKeyKeepsProviderSpecificRenderKind() {
        let request = LumiLLMRequest(messages: [], model: "test-model")

        let message = LumiLLMProviderErrorSupport.makeErrorMessage(
            providerID: "test-provider",
            conversationID: UUID(),
            request: request,
            error: LumiLLMProviderSupportError.missingAPIKey("Test Provider"),
            disposition: .nonRetryable,
            renderKind: "provider-api-key-missing"
        )

        XCTAssertEqual(message.renderKind, "provider-api-key-missing")
        XCTAssertTrue(LumiLLMProviderAPIKeyMessage.isMissingAPIKeyMessage(message))
    }

    func testAPIKeyAccessFailureUsesDistinctRenderKindAndPreservesDetails() {
        let request = LumiLLMRequest(messages: [], model: "test-model")
        let error = LumiLLMProviderSupportError.apiKeyAccessFailed(
            provider: "Test Provider",
            details: "Keychain read failed (OSStatus -25308: User interaction is not allowed.)"
        )

        let message = LumiLLMProviderErrorSupport.makeErrorMessage(
            providerID: "test-provider",
            conversationID: UUID(),
            request: request,
            error: error,
            disposition: error.llmErrorDisposition,
            renderKind: "provider-request-failed"
        )

        XCTAssertEqual(message.renderKind, LumiLLMProviderAPIKeyMessage.accessFailedRenderKind)
        XCTAssertTrue(LumiLLMProviderAPIKeyMessage.isAPIKeyAccessFailedMessage(message))
        XCTAssertFalse(LumiLLMProviderAPIKeyMessage.isMissingAPIKeyMessage(message))
        XCTAssertTrue(message.rawErrorDetail?.contains("OSStatus -25308") == true)
        XCTAssertEqual(message.metadata[LumiLLMErrorMetadata.retryable], "true")
    }
}
