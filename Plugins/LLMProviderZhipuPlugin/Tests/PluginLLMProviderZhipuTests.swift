import Foundation
import LumiCoreKit
import Testing
@testable import LLMProviderZhipuPlugin

@Suite(.serialized)
struct PluginLLMProviderZhipuTests {
    @Test func pluginMetadata() {
        #expect(ZhipuPlugin.info.id.isEmpty == false)
        #expect(ZhipuPlugin.info.displayName.isEmpty == false)
        #expect(ZhipuPlugin.info.description.isEmpty == false)
        #expect(ZhipuPlugin.iconName.isEmpty == false)
        #expect(ZhipuPlugin.category == .llmProvider)
        #expect(ZhipuPlugin.policy == .alwaysOn)
    }

    @Test func providerMetadata() {
        #expect(ZhipuProvider.info.id == "zhipu")
        #expect(ZhipuProvider.info.displayName.isEmpty == false)
        #expect(ZhipuProvider.info.defaultModel.isEmpty == false)
        #expect(ZhipuProvider.apiKeyHelpURL != nil)
    }

    @MainActor
    @Test func renderersMatchRenderKind() {
        let conversationID = UUID()
        let apiKeyMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: ZhipuProvider.info.id,
            isError: true,
            renderKind: ZhipuRenderKind.apiKeyMissing
        )
        let forbiddenMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: ZhipuProvider.info.id,
            isError: true,
            rawErrorDetail: "HTTP 403",
            renderKind: ZhipuRenderKind.http(403)
        )
        let otherProviderMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: "openai",
            isError: true,
            renderKind: ZhipuRenderKind.http(403)
        )

        #expect(ApiKeyMissingRenderer.item.canRender(apiKeyMessage))
        #expect(!ApiKeyMissingRenderer.item.canRender(forbiddenMessage))
        #expect(Http403Renderer.item.canRender(forbiddenMessage))
        #expect(!Http403Renderer.item.canRender(otherProviderMessage))
        #expect(Http403Renderer.item.order > 160)
    }

    @MainActor
    @Test func httpErrorRendererMatchesOtherStatusCodes() {
        let conversationID = UUID()
        let rateLimited = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: ZhipuProvider.info.id,
            isError: true,
            renderKind: ZhipuRenderKind.http(429)
        )
        let forbidden = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: ZhipuProvider.info.id,
            isError: true,
            renderKind: ZhipuRenderKind.http(403)
        )

        #expect(HttpErrorRenderer.item.canRender(rateLimited))
        #expect(!HttpErrorRenderer.item.canRender(forbidden))
    }

    @MainActor
    @Test func requestFailedRendererMatchesRenderKind() {
        let message = LumiChatMessage(
            conversationID: UUID(),
            role: .error,
            content: "",
            providerID: ZhipuProvider.info.id,
            isError: true,
            renderKind: ZhipuRenderKind.requestFailed
        )

        #expect(RequestFailedRenderer.item.canRender(message))
    }
}
