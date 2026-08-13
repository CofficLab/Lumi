import Foundation
import KernelLumi
import Testing
@testable import LLMProviderKimiCodePlugin

@MainActor
struct PluginLLMProviderKimiCodeTests {
    @Test func pluginMetadata() {
        #expect(KimiCodePlugin().id.isEmpty == false)
        #expect(KimiCodePlugin().name.isEmpty == false)
        #expect(KimiCodePlugin().category == .llmProvider)
    }

    @Test func openAIProviderMetadata() {
        #expect(KimiCodeOpenAIProvider.info.id == "kimi-code-openai")
        #expect(KimiCodeOpenAIProvider.info.defaultModel == "k3")
        #expect(KimiCodeOpenAIProvider.info.availableModels.contains { $0.id == "kimi-for-coding" })
        #expect(KimiCodeOpenAIProvider.info.availableModels.contains { $0.id == "kimi-for-coding-highspeed" })
    }

    @Test func anthropicProviderMetadata() {
        #expect(KimiCodeAnthropicProvider.info.id == "kimi-code-anthropic")
        #expect(KimiCodeAnthropicProvider.info.defaultModel == "k3")
        #expect(KimiCodeAnthropicProvider.info.availableModels.contains { $0.id == "kimi-for-coding" })
        #expect(KimiCodeAnthropicProvider.info.availableModels.contains { $0.id == "kimi-for-coding-highspeed" })
    }

    @Test func sharedAPIKeyStorageKey() {
        // Both providers should share the same API key storage key
        #expect(KimiCodeOpenAIProvider.info._apiKeyStorageKey == "DevAssistant_ApiKey_KimiCode")
        #expect(KimiCodeAnthropicProvider.info._apiKeyStorageKey == "DevAssistant_ApiKey_KimiCode")
    }


    @Test func anthropicToolImagesAreNestedInsideToolResult() throws {
        let attachment = LumiImageAttachment(
            mimeType: "image/png",
            base64Data: Data([0x89, 0x50, 0x4E, 0x47]).base64EncodedString(),
            fileName: "preview.png"
        )
        let message = LumiChatMessage(
            conversationID: UUID(),
            role: .tool,
            content: "已读取图片",
            metadata: LumiImageAttachmentMetadata.encode([attachment]),
            toolCallID: "call_image"
        )
        let body = AnthropicKimiCodeRequestBuilder.body(for: LumiLLMRequest(
            messages: [message],
            model: "k3"
        ))

        let messages = try #require(body["messages"] as? [[String: Any]])
        let outerContent = try #require(messages[0]["content"] as? [[String: Any]])
        let resultContent = try #require(outerContent[0]["content"] as? [[String: Any]])

        #expect(outerContent.count == 1)
        #expect(resultContent.map { $0["type"] as? String } == ["text", "image"])
    }
}
