import Foundation
import LLMKit
import Testing
import LumiCoreKit
@testable import LLMProviderZhipuPlugin

struct PluginLLMProviderZhipuTests {
    @Test func pluginMetadata() {
        #expect(ZhipuPlugin.id.isEmpty == false)
        #expect(ZhipuPlugin.displayName.isEmpty == false)
        #expect(ZhipuPlugin.description.isEmpty == false)
        #expect(ZhipuPlugin.iconName.isEmpty == false)
        #expect(ZhipuPlugin.category == .llmProvider)
        #expect(ZhipuPlugin.shared.llmProviderType() == ZhipuProvider.self)
    }

    @Test func providerMetadata() {
        #expect(ZhipuProvider.id.isEmpty == false)
        #expect(ZhipuProvider.displayName.isEmpty == false)
        #expect(ZhipuProvider.defaultModel.isEmpty == false)
        #expect(ZhipuProvider.apiKeyHelpURL != nil)
    }

    @Test func renderersMatchRenderKind() {
        let apiKeyRenderer = ApiKeyMissingRenderer()
        let forbiddenRenderer = Http403Renderer()
        let conversationId = UUID()

        let apiKeyMessage = ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: "",
            isError: true,
            providerId: ZhipuProvider.id,
            renderKind: ZhipuRenderKind.apiKeyMissing
        )
        let forbiddenMessage = ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: "",
            isError: true,
            providerId: ZhipuProvider.id,
            rawErrorDetail: "HTTP 403",
            renderKind: ZhipuRenderKind.http(403)
        )
        let otherProviderMessage = ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: "",
            isError: true,
            providerId: "openai",
            renderKind: ZhipuRenderKind.http(403)
        )

        #expect(apiKeyRenderer.canRender(message: apiKeyMessage))
        #expect(!apiKeyRenderer.canRender(message: forbiddenMessage))
        #expect(forbiddenRenderer.canRender(message: forbiddenMessage))
        #expect(!forbiddenRenderer.canRender(message: otherProviderMessage))
        #expect(Http403Renderer.priority > 160)
    }

    @Test func renderersMatchLegacyContent() {
        let forbiddenRenderer = Http403Renderer()
        let apiKeyRenderer = ApiKeyMissingRenderer()
        let conversationId = UUID()

        let legacyForbidden = ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: "__LUMI_ZHIPU_HTTP_403__",
            isError: true,
            providerId: ZhipuProvider.id
        )
        let legacyApiKey = ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: ChatMessage.apiKeyMissingSystemContentKey,
            isError: true,
            providerId: ZhipuProvider.id
        )

        #expect(forbiddenRenderer.canRender(message: legacyForbidden))
        #expect(apiKeyRenderer.canRender(message: legacyApiKey))
    }

    @Test func httpErrorRendererMatchesOtherStatusCodes() {
        let renderer = HttpErrorRenderer()
        let conversationId = UUID()

        let rateLimited = ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: "",
            isError: true,
            providerId: ZhipuProvider.id,
            renderKind: ZhipuRenderKind.http(429)
        )
        let forbidden = ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: "",
            isError: true,
            providerId: ZhipuProvider.id,
            renderKind: ZhipuRenderKind.http(403)
        )

        #expect(renderer.canRender(message: rateLimited))
        #expect(!renderer.canRender(message: forbidden))
    }

    @Test func requestFailedRendererMatchesRenderKind() {
        let renderer = RequestFailedRenderer()
        let conversationId = UUID()

        let message = ChatMessage(
            role: .error,
            conversationId: conversationId,
            content: "",
            isError: true,
            providerId: ZhipuProvider.id,
            renderKind: ZhipuRenderKind.requestFailed
        )

        #expect(renderer.canRender(message: message))
    }

    @Test func buildErrorChatMessageMapsHttp403ToRenderKind() {
        let provider = ZhipuProvider()
        let conversationId = UUID()
        let error = LLMServiceError.requestFailed("[HTTP 403] forbidden", statusCode: 403)

        let message = provider.buildErrorChatMessage(
            error: error,
            conversationId: conversationId,
            rawDetail: "HTTP 403"
        )

        #expect(message?.renderKind == ZhipuRenderKind.http(403))
        #expect(message?.content == "")
        #expect(message?.providerId == ZhipuProvider.id)
        #expect(message?.rawErrorDetail == "[HTTP 403] forbidden")
    }

    @Test func buildErrorChatMessageDispatchesThroughExistential() {
        let provider: any SuperLLMProvider = ZhipuProvider()
        let conversationId = UUID()
        let error = LLMServiceError.requestFailed("[HTTP 403] forbidden", statusCode: 403)

        let message = provider.buildErrorChatMessage(
            error: error,
            conversationId: conversationId,
            rawDetail: "HTTP 403"
        )

        #expect(message?.renderKind == ZhipuRenderKind.http(403))
        #expect(message?.providerId == ZhipuProvider.id)
        #expect(message?.rawErrorDetail == "[HTTP 403] forbidden")
        #expect(Http403Renderer().canRender(message: message!))
    }

    @Test func buildErrorChatMessageMapsApiKeyMissingToRenderKind() {
        let provider = ZhipuProvider()
        let conversationId = UUID()

        let message = provider.buildErrorChatMessage(
            error: LLMServiceError.apiKeyEmpty,
            conversationId: conversationId,
            rawDetail: nil
        )

        #expect(message?.renderKind == ZhipuRenderKind.apiKeyMissing)
        #expect(message?.content == "")
    }
}
