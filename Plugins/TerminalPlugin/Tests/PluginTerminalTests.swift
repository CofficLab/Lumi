import Testing
@testable import TerminalPlugin

@Test func packageLoads() async throws {
    #expect(Bool(true))
}

@Test func pluginPolicyIsOptOut() {
    #expect(TerminalPlugin.policy == .optOut)
    #expect(TerminalPlugin.isConfigurable == true)
}
