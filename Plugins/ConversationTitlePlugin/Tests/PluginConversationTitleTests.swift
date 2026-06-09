import LumiCoreKit
import Testing
@testable import ConversationTitlePlugin

@Test func packageLoads() async throws {
    #expect(ConversationTitlePlugin.info.id == "com.coffic.lumi.plugin.conversation-title")
}

@Test func pluginPolicyIsAlwaysOn() {
    #expect(ConversationTitlePlugin.policy == .alwaysOn)
    #expect(ConversationTitlePlugin.policy.isConfigurable == false)
}

@MainActor
@Test func pluginRegistersTitleHintMiddleware() {
    let middlewares = ConversationTitlePlugin.sendMiddlewares(
        context: LumiPluginContext(activeSectionID: "chat", activeSectionTitle: "Chat")
    )

    #expect(middlewares.count == 1)
}
