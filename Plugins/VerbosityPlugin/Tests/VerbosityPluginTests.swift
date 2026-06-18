import Testing
@testable import VerbosityPlugin

@Test func pluginPolicyIsAlwaysOn() {
    #expect(VerbosityPlugin.policy == .alwaysOn)
}
