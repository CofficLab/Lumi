import Testing
import AgentToolKit
@testable import AgentMessageRendererPlugin

@Test func packageLoads() async throws {
    #expect(true)
}

@Test func toolCallResultVisualStateReflectsFailureResults() {
    let failed = ToolCallResult(content: "Error: missing file", isError: true)
    let state = ToolCallResultVisualState(result: failed, isLoading: false)

    #expect(state == .failed)
    #expect(state.systemImage == "exclamationmark.triangle.fill")
    #expect(state.isFailure)
}

@Test func toolCallResultVisualStatePrefersLoadingUntilResultArrives() {
    let failed = ToolCallResult(content: "Error: still pending", isError: true)
    let state = ToolCallResultVisualState(result: failed, isLoading: true)

    #expect(state == .loading)
    #expect(state.systemImage == "hourglass")
    #expect(!state.isFailure)
}

@Test func toolCallResultVisualStateTreatsNonErrorResultsAsCompleted() {
    let completed = ToolCallResult(content: "ok", isError: false)
    let state = ToolCallResultVisualState(result: completed, isLoading: false)

    #expect(state == .completed)
    #expect(state.systemImage == "doc.text.magnifyingglass")
    #expect(!state.isFailure)
}
