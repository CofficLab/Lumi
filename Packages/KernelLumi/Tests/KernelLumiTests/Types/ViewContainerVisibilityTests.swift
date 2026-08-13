import Testing
@testable import KernelLumi

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

    @Test("isSupported 仅在 unsupported 时为 false")
    func isSupportedReturnsFalseOnlyForUnsupported() {
        #expect(ViewContainerVisibility.unsupported.isSupported == false)
        #expect(ViewContainerVisibility.hiddenByDefault.isSupported == true)
        #expect(ViewContainerVisibility.visibleByDefault.isSupported == true)
        #expect(ViewContainerVisibility.alwaysVisible.isSupported == true)
    }
}
