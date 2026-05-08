import Testing
@testable import EditorKernelCore

@MainActor
@Suite("LSPViewportScheduler")
struct LSPViewportSchedulerTests {
    @Test("significant viewport change respects threshold")
    func significantViewportChange() {
        let scheduler = LSPViewportScheduler()
        scheduler.recordViewport(startLine: 10, endLine: 20)

        #expect(
            scheduler.hasSignificantViewportChange(
                startLine: 15,
                endLine: 25,
                threshold: 10
            ) == false
        )
        #expect(
            scheduler.hasSignificantViewportChange(
                startLine: 21,
                endLine: 32,
                threshold: 10
            ) == true
        )
    }
}
