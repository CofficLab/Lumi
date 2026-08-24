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

    @Test("stage is .dev so the plugin manager UI can label it as scaffolding")
    func stageIsDev() {
        let plugin = MessageListAppKitPlugin()
        #expect(plugin.stage == .dev)
    }

    @Test("name matches the xcstrings key for the default locale")
    func localizedName() {
        let plugin = MessageListAppKitPlugin()
        #expect(plugin.name == "Message List (AppKit)")
    }
}
