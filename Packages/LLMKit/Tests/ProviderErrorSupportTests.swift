import LumiKernel
import XCTest
@testable import LLMKit

final class ProviderErrorSupportTests: XCTestCase {
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
}
