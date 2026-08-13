import Foundation
import Testing
import KernelLumi
@testable import ConversationNewPlugin

@MainActor
@Test func pluginPolicyIsAlwaysOn() {
    let plugin = ConversationNewPlugin()
    #expect(plugin.policy == .alwaysOn)
    #expect(plugin.policy.isConfigurable == false)
}
