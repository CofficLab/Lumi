import Testing
import Foundation
@testable import PluginInput

@Test func packageLoads() async throws {
    #expect(true)
}

@MainActor
@Test func removeRuleIgnoresStaleOffsets() {
    let viewModel = InputSettingsViewModel()
    viewModel.rules = [
        InputRule(appBundleID: "com.example.one", appName: "One", inputSourceID: "source.one")
    ]

    viewModel.removeRule(at: IndexSet([2]))

    #expect(viewModel.rules.count == 1)
}
