import KernelLumi
import Testing
@testable import SkillPlugin

@MainActor
@Test func packageLoads() async throws {
    #expect(Bool(true))
}

@MainActor
@Test func pluginPolicyIsAlwaysOn() {
    #expect(SkillPlugin().policy == .alwaysOn)
    #expect(SkillPlugin().policy.isConfigurable == false)
}

@MainActor
@Test func skillPluginPlaceholder() {}
