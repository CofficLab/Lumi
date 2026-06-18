import Testing
@testable import ConversationTimelinePlugin

@Test func pluginPolicyIsAlwaysOn() {
    #expect(ConversationTimelinePlugin.policy == .alwaysOn)
}
