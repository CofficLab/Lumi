import Foundation
import HttpKit
import LLMKit
import LumiKernel
import Testing
@testable import LLMProviderAliyunPlugin

@Suite(.serialized)
@MainActor
struct PluginLLMProviderAliyunTests {
    private func makeMessage(for error: Error, conversationID: UUID = UUID()) -> LumiChatMessage {
        let provider = AliyunProvider()
        let request = LumiLLMRequest(
            messages: [
                LumiChatMessage(conversationID: conversationID, role: .user, content: "test")
            ],
            model: AliyunProvider.info.defaultModel
        )
        let disposition = provider.retryDisposition(
            for: error,
            context: LumiLLMRetryContext(attempt: 1, maxAttempts: 3)
        )
        return provider.makeErrorMessage(
            conversationID: conversationID,
            request: request,
            error: error,
            disposition: disposition
        )
    }

    @Test func pluginMetadata() {
        #expect(AliyunPlugin().id.isEmpty == false)
        #expect(AliyunPlugin().name.isEmpty == false)
        #expect(AliyunPlugin().category == .llmProvider)
        #expect(AliyunPlugin().policy == .alwaysOn)
    }

    @Test func providerMetadata() {
        #expect(AliyunProvider.info.id == "aliyun")
        #expect(AliyunProvider.info.displayName.isEmpty == false)
        #expect(AliyunProvider.info.defaultModel.isEmpty == false)
        #expect(AliyunProvider.apiKeyHelpURL != nil)
    }

    @Test func renderersMatchRenderKind() {
        let conversationID = UUID()
        let apiKeyMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: AliyunProvider.info.id,
            isError: true,
            renderKind: AliyunRenderKind.apiKeyMissing
        )
        let forbiddenMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: AliyunProvider.info.id,
            isError: true,
            rawErrorDetail: "HTTP 403",
            renderKind: AliyunRenderKind.http(403)
        )
        let otherProviderMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: "zhipu",
            isError: true,
            renderKind: AliyunRenderKind.http(403)
        )

        #expect(ApiKeyMissingRenderer.item.canRender(apiKeyMessage))
        #expect(!ApiKeyMissingRenderer.item.canRender(forbiddenMessage))
        #expect(Http403Renderer.item.canRender(forbiddenMessage))
        #expect(!Http403Renderer.item.canRender(otherProviderMessage))
        #expect(Http403Renderer.item.order > 160)

        let unauthorizedMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: AliyunProvider.info.id,
            isError: true,
            rawErrorDetail: "HTTP 错误 (401): invalid_api_key",
            renderKind: AliyunRenderKind.http(401)
        )

        #expect(Http401Renderer.item.canRender(unauthorizedMessage))
        #expect(!ApiKeyMissingRenderer.item.canRender(unauthorizedMessage))
    }

    @Test func buildRequestUsesAnthropicCompatibleHeaders() {
        let service = AliyunAnthropicService(baseURL: "https://coding.dashscope.aliyuncs.com/apps/anthropic")
        let body = "{}".data(using: .utf8)!
        let request = try! service.makeRequest(apiKey: "sk-sp-test", body: body)

        #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-sp-test")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func httpErrorRendererMatchesOtherStatusCodes() {
        let conversationID = UUID()
        let rateLimited = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: AliyunProvider.info.id,
            isError: true,
            renderKind: AliyunRenderKind.http(429)
        )
        let forbidden = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: AliyunProvider.info.id,
            isError: true,
            renderKind: AliyunRenderKind.http(403)
        )

        #expect(HttpErrorRenderer.item.canRender(rateLimited))
        #expect(!HttpErrorRenderer.item.canRender(forbidden))
    }

    @Test func errorMessageMapsMissingAPIKey() {
        let message = makeMessage(
            for: LumiLLMProviderSupportError.missingAPIKey(AliyunProvider.info.displayName)
        )

        #expect(message.renderKind == AliyunRenderKind.apiKeyMissing)
        #expect(message.providerID == AliyunProvider.info.id)
        #expect(message.isError)
        #expect(message.metadata[LumiLLMErrorMetadata.retryable] == "false")
    }

    @Test func errorMessageMapsHTTP401FromHTTPClientError() {
        let message = makeMessage(
            for: HTTPClientError.httpError(statusCode: 401, message: "invalid_api_key")
        )

        #expect(message.renderKind == AliyunRenderKind.http(401))
        #expect(message.rawErrorDetail == "invalid_api_key")
        #expect(message.metadata[LLMTransportMetadata.responseDetails]?.contains("invalid_api_key") == true)
        #expect(message.metadata[LumiLLMErrorMetadata.retryable] == "false")
    }

    @Test func errorMessageMapsHTTP429AsRetryable() {
        let message = makeMessage(
            for: HTTPClientError.httpError(statusCode: 429, message: "rate limited")
        )

        #expect(message.renderKind == AliyunRenderKind.http(429))
        #expect(message.metadata[LumiLLMErrorMetadata.retryable] == "true")
    }

    @Test func errorMessageMapsHTTP401FromStreamingFailedWithTransportMetadata() {
        let transport = """
        Request URL: https://example.com/v1/messages
        Response Status: 401
        Response Body: invalid_api_key
        """
        let full = "invalid_api_key" + LLMTransportDetails.summarySeparator + transport
        let message = makeMessage(
            for: LumiLLMProviderSupportError.streamingFailed(full)
        )

        #expect(message.renderKind == AliyunRenderKind.http(401))
        #expect(message.rawErrorDetail == "invalid_api_key")
        #expect(message.metadata[LLMTransportMetadata.requestDetails]?.contains("Request URL") == true)
    }

    @Test func unsupportedModelAvailabilityMapsToStructuredFailure() {
        let body = #"{"error":{"code":"invalid_parameter_error","message":"model not supported"}}"#
        let error = HTTPClientError.httpError(statusCode: 400, message: body)

        #expect(AliyunAvailabilityService.isUnsupportedModelError(error))

        let mapped = AliyunAvailabilityService.mapUnsupportedModelResult(
            .unavailable(LumiLLMFailureDetailResolver.resolve(from: error))
        )

        guard case .unavailable(let failure) = mapped else {
            Issue.record("Expected unavailable result")
            return
        }

        #expect(failure.reason == LumiLLMFailureReason.unsupportedModel)
        #expect(!failure.availabilityDisplayText.contains("invalid_parameter"))
        #expect(!failure.availabilityDisplayText.contains("URL:"))
        #expect(failure.hasTransportDiagnostics)
        #expect(failure.transportDetails?.contains("invalid_parameter") == true)
        #expect(failure.httpStatusCode == 400)
    }
}
