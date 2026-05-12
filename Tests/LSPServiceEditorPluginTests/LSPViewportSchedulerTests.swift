#if canImport(XCTest)
import XCTest
import EditorKernelCore
@testable import Lumi

@MainActor
final class LSPViewportSchedulerTests: XCTestCase {
    func testCancelAllStopsPendingTasks() async {
        let scheduler = LSPViewportScheduler()

        var executed = false
        scheduler.scheduleInlayHints(debounceMs: 50) {
            executed = true
        }

        scheduler.cancelAll()
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertFalse(executed)
    }

    func testScheduleInlayHintsDebounces() async {
        let scheduler = LSPViewportScheduler()

        var executionCount = 0
        scheduler.scheduleInlayHints(debounceMs: 50) {
            executionCount += 1
        }
        scheduler.scheduleInlayHints(debounceMs: 50) {
            executionCount += 1
        }
        scheduler.scheduleInlayHints(debounceMs: 50) {
            executionCount += 1
        }

        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(executionCount, 1)
    }

    func testScheduleDiagnosticsDebounces() async {
        let scheduler = LSPViewportScheduler()

        var executionCount = 0
        scheduler.scheduleDiagnostics(debounceMs: 30) {
            executionCount += 1
        }
        scheduler.scheduleDiagnostics(debounceMs: 30) {
            executionCount += 1
        }

        try? await Task.sleep(for: .milliseconds(60))

        XCTAssertEqual(executionCount, 1)
    }

    func testScheduleCodeActionsDebounces() async {
        let scheduler = LSPViewportScheduler()

        var executionCount = 0
        scheduler.scheduleCodeActions(debounceMs: 30) {
            executionCount += 1
        }
        scheduler.scheduleCodeActions(debounceMs: 30) {
            executionCount += 1
        }

        try? await Task.sleep(for: .milliseconds(60))

        XCTAssertEqual(executionCount, 1)
    }

    func testRecordViewportTracksSignificantChangeThreshold() {
        let scheduler = LSPViewportScheduler()

        scheduler.recordViewport(startLine: 100, endLine: 120)

        XCTAssertTrue(scheduler.hasSignificantViewportChange(startLine: 115, endLine: 135, threshold: 10))
        XCTAssertFalse(scheduler.hasSignificantViewportChange(startLine: 105, endLine: 125, threshold: 10))
    }

    func testCancelSpecificTypeLeavesOtherScheduledWorkIntact() async {
        let scheduler = LSPViewportScheduler()

        var inlayExecuted = false
        var diagnosticsExecuted = false

        scheduler.scheduleInlayHints(debounceMs: 30) {
            inlayExecuted = true
        }
        scheduler.scheduleDiagnostics(debounceMs: 30) {
            diagnosticsExecuted = true
        }

        scheduler.cancel(.inlayHints)
        try? await Task.sleep(for: .milliseconds(60))

        XCTAssertFalse(inlayExecuted)
        XCTAssertTrue(diagnosticsExecuted)
    }

    func testDefaultDebounceConstantsRemainStable() {
        XCTAssertEqual(LSPViewportScheduler.inlayHintsDebounceMs, 500)
        XCTAssertEqual(LSPViewportScheduler.diagnosticsDebounceMs, 300)
        XCTAssertEqual(LSPViewportScheduler.codeActionsDebounceMs, 400)
    }
}
#endif
