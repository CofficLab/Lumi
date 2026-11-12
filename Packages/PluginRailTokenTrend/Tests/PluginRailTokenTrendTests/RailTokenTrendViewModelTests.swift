import Testing
@testable import PluginRailTokenTrend

@Suite("RailTokenTrendViewModel")
@MainActor
struct RailTokenTrendViewModelTests {
    @Test("initial state is empty")
    func initialState() {
        let viewModel = RailTokenTrendViewModel(messages: nil)
        #expect(viewModel.days.isEmpty)
        #expect(viewModel.totalTokens == 0)
        #expect(viewModel.isLoading == false)
    }

    @Test("loadTrend does nothing without messages provider")
    func loadTrendWithoutMessages() {
        let viewModel = RailTokenTrendViewModel(messages: nil)
        viewModel.loadTrend()
        // Should remain empty since messages is nil
        #expect(viewModel.days.isEmpty)
        #expect(viewModel.totalTokens == 0)
    }
}
