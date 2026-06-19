@testable import EditorSwiftPlugin
import Testing
import XcodeKit

@MainActor
@Test func windowScopeCreatesDistinctViewModels() {
    let first = EditorSwiftWindowScope()
    let second = EditorSwiftWindowScope()
    #expect(first.statusBarViewModel !== second.statusBarViewModel)
}

@MainActor
@Test func statusBarViewModelResetClearsSchemeState() {
    let viewModel = XcodeProjectStatusBarViewModel()
    viewModel.schemes = ["A", "B"]
    viewModel.activeScheme = "A"

    viewModel.resetDisplayedStateForTesting()

    #expect(viewModel.schemes.isEmpty)
    #expect(viewModel.activeScheme == nil)
}
