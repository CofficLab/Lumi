import Testing
@testable import VerbosityPlugin

@Test func packageLoads() async throws {
    #expect(true)
}

@Test func pluginPolicyIsAlwaysOn() {
    #expect(VerbosityPlugin.policy == .alwaysOn)
    #expect(VerbosityPlugin.isConfigurable == false)
}
