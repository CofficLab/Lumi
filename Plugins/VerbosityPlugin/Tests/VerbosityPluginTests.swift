import Testing
@testable import VerbosityPlugin

@MainActor
@Test func pluginPolicyIsAlwaysOn() {
    #expect(VerbosityPlugin().policy == .alwaysOn)
}
