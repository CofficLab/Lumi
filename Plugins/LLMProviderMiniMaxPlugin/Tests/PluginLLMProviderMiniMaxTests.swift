import Foundation
import HttpKit
import LumiKernel
import LLMKit
import LumiKernel
import Testing
@testable import LLMProviderMiniMaxPlugin

@Suite(.serialized)
struct PluginLLMProviderMiniMaxTests {
    private func makeMessage(for error: Error, conversationID: UUID = UUID()) -> LumiChatMessage {
        let provider = MiniMaxTokenPlanProvider()
        let request = LumiLLMRequest(
            messages: [
                LumiChatMessage(conversationID: conversationID, role: .user, content: "test")
            ],
            model: MiniMaxTokenPlanProvider.info.defaultModel
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
        #expect(MiniMaxPlugin.info.id.isEmpty == false)
        #expect(MiniMaxPlugin.info.displayName.isEmpty == false)
        #expect(MiniMaxPlugin.info.description.isEmpty == false)
        #expect(MiniMaxPlugin.iconName.isEmpty == false)
        #expect(MiniMaxPlugin.category == .llmProvider)
        #expect(MiniMaxPlugin.policy == .alwaysOn)
    }

    @Test func providerMetadata() {
        #expect(MiniMaxTokenPlanProvider.info.id == "minimax-tokenplan")
        #expect(MiniMaxTokenPlanProvider.info.displayName.isEmpty == false)
        #expect(MiniMaxTokenPlanProvider.info.defaultModel == "MiniMax-M2.7")
        #expect(MiniMaxTokenPlanProvider.apiKeyHelpURL != nil)
        #expect(MiniMaxTokenPlanProvider.info.availableModels.contains("MiniMax-M3"))
        #expect(MiniMaxTokenPlanProvider.info.availableModels.contains("MiniMax-M2.7"))
        #expect(MiniMaxTokenPlanProvider.info.availableModels.contains("MiniMax-M2.7-highspeed"))
        #expect(MiniMaxTokenPlanProvider.info.availableModels.contains("MiniMax-M2.5"))
    }

    @MainActor
    @Test func renderersMatchRenderKind() {
        let conversationID = UUID()
        let apiKeyMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: MiniMaxTokenPlanProvider.info.id,
            isError: true,
            renderKind: MiniMaxRenderKind.apiKeyMissing
        )
        let forbiddenMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: MiniMaxTokenPlanProvider.info.id,
            isError: true,
            rawErrorDetail: "HTTP 403",
            renderKind: MiniMaxRenderKind.http(403)
        )
        let otherProviderMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: "zhipu",
            isError: true,
            renderKind: MiniMaxRenderKind.http(403)
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
            providerID: MiniMaxTokenPlanProvider.info.id,
            isError: true,
            rawErrorDetail: "HTTP 错误 (401): invalid_api_key",
            renderKind: MiniMaxRenderKind.http(401)
        )

        #expect(Http401Renderer.item.canRender(unauthorizedMessage))
        #expect(!ApiKeyMissingRenderer.item.canRender(unauthorizedMessage))
    }

    @Test func buildRequestUsesAnthropicCompatibleHeaders() {
        let provider = MiniMaxTokenPlanProvider()
        let url = URL(string: "https://api.minimax.chat/anthropic/v1/messages")!
        let request = provider.buildRequest(url: url, apiKey: "minimax-test-key")

        #expect(request.value(forHTTPHeaderField: "x-api-key") == "minimax-test-key")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @MainActor
    @Test func httpErrorRendererMatchesOtherStatusCodes() {
        let conversationID = UUID()
        let rateLimited = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: MiniMaxTokenPlanProvider.info.id,
            isError: true,
            renderKind: MiniMaxRenderKind.http(429)
        )
        let forbidden = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: MiniMaxTokenPlanProvider.info.id,
            isError: true,
            renderKind: MiniMaxRenderKind.http(403)
        )

        #expect(HttpErrorRenderer.item.canRender(rateLimited))
        #expect(!HttpErrorRenderer.item.canRender(forbidden))
    }

    @Test func errorMessageMapsMissingAPIKey() {
        let message = makeMessage(
            for: LumiLLMProviderSupportError.missingAPIKey(MiniMaxTokenPlanProvider.info.displayName)
        )

        #expect(message.renderKind == MiniMaxRenderKind.apiKeyMissing)
        #expect(message.providerID == MiniMaxTokenPlanProvider.info.id)
        #expect(message.isError)
        #expect(message.metadata[LumiLLMErrorMetadata.retryable] == "false")
    }

    @Test func errorMessageMapsHTTP401FromHTTPClientError() {
        let message = makeMessage(
            for: HTTPClientError.httpError(statusCode: 401, message: "invalid_api_key")
        )

        #expect(message.renderKind == MiniMaxRenderKind.http(401))
        #expect(message.rawErrorDetail == "invalid_api_key")
        #expect(message.metadata[LLMTransportMetadata.responseDetails]?.contains("invalid_api_key") == true)
        #expect(message.metadata[LumiLLMErrorMetadata.retryable] == "false")
    }

    @Test func errorMessageMapsHTTP429AsRetryable() {
        let message = makeMessage(
            for: HTTPClientError.httpError(statusCode: 429, message: "rate limited")
        )

        #expect(message.renderKind == MiniMaxRenderKind.http(429))
        #expect(message.metadata[LumiLLMErrorMetadata.retryable] == "true")
    }

    @Test func unsupportedModelAvailabilityMapsToStructuredFailure() {
        let body = #"{"error":{"code":"invalid_parameter_error","message":"model not supported"}}"#
        let error = HTTPClientError.httpError(statusCode: 400, message: body)

        #expect(AvailabilityService.isUnsupportedModelError(error))

        let mapped = AvailabilityService.mapUnsupportedModelResult(
            .unavailable(LLMFailureDetailResolver.resolve(from: error))
        )

        guard case .unavailable(let failure) = mapped else {
            Issue.record("Expected unavailable result")
            return
        }

        #expect(failure.reason == .unsupportedModel)
        #expect(!failure.availabilityDisplayText.contains("invalid_parameter"))
        #expect(!failure.availabilityDisplayText.contains("URL:"))
        #expect(failure.hasTransportDiagnostics)
        #expect(failure.transportDetails?.contains("invalid_parameter") == true)
        #expect(failure.httpStatusCode == 400)
    }

    @Test func unsupportedModelDetectsModelNotFoundInResponse() {
        let body = #"{"error":{"code":"model_not_found","message":"MiniMax-M2.7 is unavailable"}}"#

        #expect(AvailabilityService.isUnsupportedModelResponse(body))
    }

    @Test func renderKindParsingRoundTripsHTTPStatusCode() {
        let renderKind = MiniMaxRenderKind.http(429)

        #expect(MiniMaxRenderKind.httpStatusCode(from: renderKind) == 429)
        #expect(MiniMaxRenderKind.httpStatusCode(from: "aliyun-http-429") == nil)
    }
}