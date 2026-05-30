import Testing
@testable import PluginEditorXcode

@Test func packageLoads() async throws {
    #expect(true)
}

@Test func schemeDeduplicationPreservesXcodebuildOrder() {
    let schemes = ["App", "Widget", "App", "Tests", "Widget", "Package"]

    let result = XcodeSchemeList.uniquePreservingOrder(schemes)

    #expect(result == ["App", "Widget", "Tests", "Package"])
}
