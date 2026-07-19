import LumiKernel
import Testing
@testable import SkillPlugin

@Test func packageLoads() async throws {
    #expect(Bool(true))
}

@Test func pluginPolicyIsAlwaysOn() {
    #expect(SkillPlugin.policy == .alwaysOn)
    #expect(SkillPlugin.policy.isConfigurable == false)
}

@MainActor
@Test func skillPluginContributesSendMiddleware() {
    let context = LumiPluginContext(activeSectionID: "chat", activeSectionTitle: "Chat")
    #expect(SkillPlugin.sendMiddlewares(context: context).count == 1)
}
