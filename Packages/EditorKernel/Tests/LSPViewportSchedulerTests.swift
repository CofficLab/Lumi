import Testing
@testable import EditorKernel

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

    @Test("Kind defaultPriority returns correct priority")
    func kindDefaultPriority() {
        #expect(LSPViewportScheduler.Kind.codeActions.defaultPriority == .high)
        #expect(LSPViewportScheduler.Kind.diagnostics.defaultPriority == .medium)
        #expect(LSPViewportScheduler.Kind.inlayHints.defaultPriority == .low)
    }

    @Test("Kind defaultDebounceMs returns correct values")
    func kindDefaultDebounceMs() {
        #expect(LSPViewportScheduler.Kind.inlayHints.defaultDebounceMs == 500)
        #expect(LSPViewportScheduler.Kind.diagnostics.defaultDebounceMs == 300)
        #expect(LSPViewportScheduler.Kind.codeActions.defaultDebounceMs == 400)
    }

    @Test("Priority comparison works correctly")
    func priorityComparison() {
        #expect(LSPViewportScheduler.Priority.low < LSPViewportScheduler.Priority.medium)
        #expect(LSPViewportScheduler.Priority.medium < LSPViewportScheduler.Priority.high)
        #expect(LSPViewportScheduler.Priority.low < LSPViewportScheduler.Priority.high)
        #expect(!(LSPViewportScheduler.Priority.high < LSPViewportScheduler.Priority.low))
        #expect(!(LSPViewportScheduler.Priority.medium < LSPViewportScheduler.Priority.medium))
    }

    @Test("cancelAll cancels all tasks")
    func cancelAll() async {
        let scheduler = LSPViewportScheduler()
        var executed = false

        // Schedule a task with long debounce
        scheduler.schedule(.inlayHints, debounceMs: 1000) {
            executed = true
        }

        // Cancel all immediately
        scheduler.cancelAll()

        // Wait a bit to ensure task would have started if not cancelled
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        #expect(executed == false)
    }

    @Test("high priority task cancels lower priority tasks")
    func highPriorityCancelsLower() async {
        let scheduler = LSPViewportScheduler()
        var inlayHintsExecuted = false
        var diagnosticsExecuted = false
        var codeActionsExecuted = false

        // Schedule low priority task
        scheduler.schedule(.inlayHints, debounceMs: 100) {
            inlayHintsExecuted = true
        }

        // Schedule medium priority task
        scheduler.schedule(.diagnostics, debounceMs: 100) {
            diagnosticsExecuted = true
        }

        // Schedule high priority task - should cancel lower ones
        scheduler.schedule(.codeActions, debounceMs: 100) {
            codeActionsExecuted = true
        }

        // Wait for tasks to potentially execute
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        #expect(inlayHintsExecuted == false)
        #expect(diagnosticsExecuted == false)
        #expect(codeActionsExecuted == true)
    }

    @Test("cancelBelow cancels tasks below specified priority")
    func cancelBelowPriority() async {
        let scheduler = LSPViewportScheduler()
        var inlayHintsExecuted = false
        var diagnosticsExecuted = false
        var codeActionsExecuted = false

        // Schedule tasks
        scheduler.schedule(.inlayHints, debounceMs: 100) {
            inlayHintsExecuted = true
        }
        scheduler.schedule(.diagnostics, debounceMs: 100) {
            diagnosticsExecuted = true
        }
        scheduler.schedule(.codeActions, debounceMs: 100) {
            codeActionsExecuted = true
        }

        // Cancel below medium priority (should cancel low priority)
        scheduler.cancelBelow(.medium)

        // Wait for tasks to potentially execute
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        #expect(inlayHintsExecuted == false)
        #expect(diagnosticsExecuted == true)
        #expect(codeActionsExecuted == true)
    }

    @Test("disableCancelLowerPriority prevents cancellation")
    func disableCancelLowerPriority() async {
        let scheduler = LSPViewportScheduler()
        var inlayHintsExecuted = false
        var codeActionsExecuted = false

        // Schedule low priority task
        scheduler.schedule(.inlayHints, debounceMs: 100) {
            inlayHintsExecuted = true
        }

        // Schedule high priority task with cancelLowerPriority = false
        scheduler.schedule(.codeActions, priority: .high, cancelLowerPriority: false, debounceMs: 100) {
            codeActionsExecuted = true
        }

        // Wait for tasks to potentially execute
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms

        // Both should execute because we disabled cancellation
        #expect(inlayHintsExecuted == true)
        #expect(codeActionsExecuted == true)
    }
}
