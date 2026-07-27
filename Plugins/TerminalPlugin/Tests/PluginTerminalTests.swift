import Testing
@testable import TerminalPlugin

@Test func packageLoads() async throws {
    #expect(Bool(true))
}

@MainActor
@Test func pluginPolicyIsOptOut() {
    let plugin = TerminalPlugin()
    #expect(plugin.policy == .optOut)
    #expect(plugin.policy.isConfigurable == true)
}
