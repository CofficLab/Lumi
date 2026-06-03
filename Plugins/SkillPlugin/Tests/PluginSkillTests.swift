import Testing
@testable import SkillPlugin

@Test func packageLoads() async throws {
    #expect(Bool(true))
}

@Test func pluginPolicyIsAlwaysOn() {
    #expect(SkillPlugin.policy == .alwaysOn)
    #expect(SkillPlugin.isConfigurable == false)
}
