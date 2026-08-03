import Testing
@testable import TerminalPlugin

@Test func packageLoads() async throws {
    #expect(Bool(true))
}

@MainActor
@Test func pluginPolicyIsOptIn() {
    let plugin = TerminalPlugin()
        #expect(plugin.policy == .optIn)
    #expect(plugin.policy.isConfigurable == true)
}
