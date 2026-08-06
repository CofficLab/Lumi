import Testing
@testable import MessageListAppKitPlugin

@MainActor
@Suite("MessageListAppKitPlugin.Policy")
struct PluginPolicyTests {
    @Test("id matches the documented value")
    func identifier() {
        let plugin = MessageListAppKitPlugin()
        #expect(plugin.id == "com.coffic.lumi.plugin.message-list-appkit")
    }

    @Test("order matches the documented value")
    func ordering() {
        let plugin = MessageListAppKitPlugin()
        #expect(plugin.order == 82)
    }

    @Test("policy is .disabled")
    func policyIsDisabled() {
        let plugin = MessageListAppKitPlugin()
        #expect(plugin.policy == .disabled)
    }

    @Test("policy.shouldRegister is false so PluginManager will not register it")
    func shouldRegister() {
        let plugin = MessageListAppKitPlugin()
        #expect(plugin.policy.shouldRegister == false)
    }
}
