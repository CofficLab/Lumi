import Testing
@testable import LumiKernel

@Suite("ViewContainerVisibility")
struct ViewContainerVisibilityTests {
    @Test("固定策略忽略用户覆盖")
    func fixedPoliciesIgnoreUserOverride() {
        #expect(ViewContainerVisibility.unsupported.resolvedVisibility(userOverride: true) == false)
        #expect(ViewContainerVisibility.alwaysVisible.resolvedVisibility(userOverride: false) == true)
    }

    @Test("可配置策略遵从默认值和用户覆盖")
    func configurablePoliciesResolveDefaultAndOverride() {
        #expect(ViewContainerVisibility.hiddenByDefault.resolvedVisibility(userOverride: nil) == false)
        #expect(ViewContainerVisibility.hiddenByDefault.resolvedVisibility(userOverride: true) == true)
        #expect(ViewContainerVisibility.visibleByDefault.resolvedVisibility(userOverride: nil) == true)
        #expect(ViewContainerVisibility.visibleByDefault.resolvedVisibility(userOverride: false) == false)
    }
}
