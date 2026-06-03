import Testing
@testable import ScreenshotPlugin

@Test func packageLoads() async throws {
    #expect(Bool(true))
}

@Test func pluginPolicyIsAlwaysOn() {
    #expect(ScreenshotPlugin.policy == .alwaysOn)
    #expect(ScreenshotPlugin.isConfigurable == false)
}
