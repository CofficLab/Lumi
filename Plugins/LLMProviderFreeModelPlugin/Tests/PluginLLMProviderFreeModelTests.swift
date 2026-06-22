import Testing
@testable import LLMProviderFreeModelPlugin

struct PluginLLMProviderFreeModelTests {
    @Test func pluginMetadata() {
        #expect(FreeModelPlugin.id.isEmpty == false)
        #expect(FreeModelPlugin.displayName.isEmpty == false)
        #expect(FreeModelPlugin.description.isEmpty == false)
        #expect(FreeModelPlugin.iconName.isEmpty == false)
        #expect(FreeModelPlugin.category == .llmProvider)
    }

    @Test func providerMetadata() {
        #expect(FreeModelProvider.info.id == "freemodel")
        #expect(FreeModelProvider.info.availableModels.contains("gpt-5.4"))
        #expect(FreeModelProvider.info.availableModels.contains("claude-sonnet-4-6"))
    }

    @Test func modelRoutingEndpoints() {
        #expect(FreeModelProvider.Endpoints.openAIPrimary == "https://api.freemodel.dev/v1/chat/completions")
        #expect(FreeModelProvider.Endpoints.openAIFallback == "https://vip-sg.freemodel.dev/v1/chat/completions")
        #expect(FreeModelProvider.Endpoints.claudeT0 == "https://cc.freemodel.dev/v1/messages")
        #expect(FreeModelProvider.Endpoints.claudeT1 == "https://api-cc.freemodel.dev/v1/messages")
        #expect(FreeModelProvider.claudeT1Models.contains("claude-opus-4-8"))
        #expect(!FreeModelProvider.claudeT1Models.contains("claude-sonnet-4-6"))
    }

    @Test func claudeCodeFingerprint() {
        let fingerprint = FreeModelClaudeCodeEmulation.computeFingerprint(firstUserMessageText: "hello")
        #expect(fingerprint.count == 3)
        #expect(FreeModelClaudeCodeEmulation.userAgent() == "claude-cli/2.1.1 (external, cli)")
        #expect(FreeModelClaudeCodeEmulation.isGatewayRejection("Please use Claude Code CLI"))
    }
}
