import Foundation
import LumiKernel
import Testing
@testable import ConversationTitlePlugin

@MainActor
@Test func packageLoads() async throws {
    let plugin = ConversationTitlePlugin()
    #expect(plugin.id == "com.coffic.lumi.plugin.conversation-title")
}

@MainActor
@Test func pluginPolicyIsAlwaysOn() {
    let plugin = ConversationTitlePlugin()
    #expect(plugin.policy == .alwaysOn)
    #expect(plugin.policy.isConfigurable == false)
}

@MainActor
@Test func pluginRegistersTitleHintMiddleware() {
    let middlewares = ConversationTitlePlugin.sendMiddlewares(lumiCore: ())

    #expect(middlewares.count == 1)
}

@MainActor
@Test func pluginRegistersTitleTool() {
    let tools = ConversationTitlePlugin.agentTools(lumiCore: ())

    #expect(tools.map(\.name).contains("update_conversation_title"))
}
