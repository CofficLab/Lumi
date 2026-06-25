import Foundation
import HttpKit
import LumiCoreKit
import LumiLLMProviderSupport
import Testing
@testable import LLMProviderAliyunPlugin

@Suite(.serialized)
struct PluginLLMProviderAliyunTests {
    @Test func pluginMetadata() {
        #expect(AliyunPlugin.info.id.isEmpty == false)
        #expect(AliyunPlugin.info.displayName.isEmpty == false)
        #expect(AliyunPlugin.info.description.isEmpty == false)
        #expect(AliyunPlugin.iconName.isEmpty == false)
        #expect(AliyunPlugin.category == .llmProvider)
        #expect(AliyunPlugin.policy == .alwaysOn)
    }

    @Test func providerMetadata() {
        #expect(AliyunProvider.info.id == "aliyun")
        #expect(AliyunProvider.info.displayName.isEmpty == false)
        #expect(AliyunProvider.info.defaultModel.isEmpty == false)
        #expect(AliyunProvider.apiKeyHelpURL != nil)
    }

    @MainActor
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
        let provider = AliyunProvider()
        let url = URL(string: "https://coding.dashscope.aliyuncs.com/apps/anthropic/v1/messages")!
        let request = provider.buildRequest(url: url, apiKey: "sk-sp-test")

        #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-sp-test")
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
        let message = AliyunProvider.errorMessage(
            conversationID: UUID(),
            error: LumiLLMProviderSupportError.missingAPIKey(AliyunProvider.info.displayName)
        )

        #expect(message.renderKind == AliyunRenderKind.apiKeyMissing)
        #expect(message.providerID == AliyunProvider.info.id)
        #expect(message.isError)
    }

    @Test func errorMessageMapsHTTP401FromHTTPClientError() {
        let message = AliyunProvider.errorMessage(
            conversationID: UUID(),
            error: HTTPClientError.httpError(statusCode: 401, message: "invalid_api_key")
        )

        #expect(message.renderKind == AliyunRenderKind.http(401))
        #expect(message.rawErrorDetail?.contains("401") == true)
        #expect(message.rawErrorDetail?.contains("invalid_api_key") == true)
    }

    @Test func errorMessageMapsHTTP401FromLocalizedStreamingFailed() {
        let detail = LumiLLMProviderSupportLocalization.userFacingDescription(
            for: HTTPClientError.httpError(statusCode: 401, message: "invalid_api_key"),
            locale: Locale(identifier: "zh-Hans")
        )
        let message = AliyunProvider.errorMessage(
            conversationID: UUID(),
            error: LumiLLMProviderSupportError.streamingFailed(detail)
        )

        #expect(message.renderKind == AliyunRenderKind.http(401))
        #expect(message.rawErrorDetail == detail)
    }
}
