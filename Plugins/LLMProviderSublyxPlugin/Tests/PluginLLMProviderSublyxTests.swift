import Foundation
import HttpKit
import LumiCoreKit
import LLMKit
import LumiCoreKit
import Testing
@testable import LLMProviderSublyxPlugin

struct PluginLLMProviderSublyxTests {
    @Test func pluginMetadata() {
        #expect(SublyxPlugin.info.id.isEmpty == false)
        #expect(SublyxPlugin.info.displayName.isEmpty == false)
        #expect(SublyxPlugin.info.description.isEmpty == false)
        #expect(SublyxPlugin.iconName.isEmpty == false)
        #expect(SublyxPlugin.category == .llmProvider)
    }

    @Test func providerMetadata() {
        #expect(SublyxProvider.info.id == "sublyx")
        #expect(SublyxProvider.info.displayName == "Sublyx")
        #expect(SublyxProvider.info.defaultModel == "gpt-5.5")
        #expect(SublyxProvider.info.availableModels.contains("gpt-5.5"))
        #expect(SublyxProvider.info.availableModels.contains("gpt-4o"))
    }

    @MainActor
    @Test func renderersMatchRenderKind() {
        let conversationID = UUID()
        let apiKeyMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: SublyxProvider.info.id,
            isError: true,
            renderKind: SublyxRenderKind.apiKeyMissing
        )
        let forbiddenMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: SublyxProvider.info.id,
            isError: true,
            rawErrorDetail: "HTTP 403",
            renderKind: SublyxRenderKind.http(403)
        )
        let otherProviderMessage = LumiChatMessage(
            conversationID: conversationID,
            role: .error,
            content: "",
            providerID: "openai",
            isError: true,
            renderKind: SublyxRenderKind.http(403)
        )

        #expect(SublyxApiKeyMissingRenderer.item.canRender(apiKeyMessage))
        #expect(!SublyxApiKeyMissingRenderer.item.canRender(forbiddenMessage))
    }

    @Test func errorRenderKindReturnsApiKeyMissing() {
        let missingKeyError = LumiLLMProviderSupportError.missingAPIKey("Sublyx")
        let provider = SublyxProvider()

        let renderKind = provider.errorRenderKind(for: missingKeyError)

        #expect(renderKind == SublyxRenderKind.apiKeyMissing)
    }

    @Test func errorRenderKindReturnsHttpStatusCode() {
        let httpError = HTTPClientError.httpError(statusCode: 401, message: "Unauthorized")
        let provider = SublyxProvider()

        let renderKind = provider.errorRenderKind(for: httpError)

        #expect(renderKind == SublyxRenderKind.http(401))
    }
}
