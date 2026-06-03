import Testing
@testable import ConversationTitlePlugin

@Test func packageLoads() async throws {
    #expect(Bool(true))
}

@Test func pluginPolicyIsAlwaysOn() {
    #expect(ConversationTitlePlugin.policy == .alwaysOn)
    #expect(ConversationTitlePlugin.isConfigurable == false)
}
