#if canImport(XCTest)
import XCTest
@testable import Lumi

final class LSPViewportSchedulerTests: XCTestCase {

    @MainActor
    func testCancelAllStopsPendingTasks() async {
        let scheduler = LSPViewportScheduler()

        var executed = false
        scheduler.scheduleInlayHints(debounceMs: 50) {
            executed = true
        }

        // 立即取消所有任务
        scheduler.cancelAll()

        // 等待超过 debounce 时间
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertFalse(executed, "Cancelled task should not execute")
    }

    @MainActor
    func testScheduleInlayHintsDebounces() async {
        let scheduler = LSPViewportScheduler()

        var executionCount = 0
        scheduler.scheduleInlayHints(debounceMs: 50) {
            executionCount += 1
        }
        // 快速连续调度，应该只保留最后一个
        scheduler.scheduleInlayHints(debounceMs: 50) {
            executionCount += 1
        }
        scheduler.scheduleInlayHints(debounceMs: 50) {
            executionCount += 1
        }

        // 等待 debounce 完成
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(executionCount, 1, "Only the last scheduled task should execute")
    }

    @MainActor
    func testScheduleInlayHintsExecutesAfterDelay() async {
        let scheduler = LSPViewportScheduler()

        var executed = false
        scheduler.scheduleInlayHints(debounceMs: 30) {
            executed = true
        }

        XCTAssertFalse(executed, "Should not execute immediately")

        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(executed, "Should execute after debounce delay")
    }

    @MainActor
    func testRecordViewport() {
        let scheduler = LSPViewportScheduler()

        scheduler.recordViewport(startLine: 100, endLine: 120)
        XCTAssertTrue(scheduler.hasSignificantViewportChange(startLine: 115, endLine: 135, threshold: 10))
        XCTAssertFalse(scheduler.hasSignificantViewportChange(startLine: 105, endLine: 125, threshold: 10))
    }

    @MainActor
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

    @MainActor
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

    @MainActor
    func testCancelSpecificType() async {
        let scheduler = LSPViewportScheduler()

        var inlayExecuted = false
        var diagnosticsExecuted = false

        scheduler.scheduleInlayHints(debounceMs: 30) {
            inlayExecuted = true
        }
        scheduler.scheduleDiagnostics(debounceMs: 30) {
            diagnosticsExecuted = true
        }

        // 只取消 inlay hints
        scheduler.cancel(.inlayHints)

        try? await Task.sleep(for: .milliseconds(60))

        XCTAssertFalse(inlayExecuted, "Inlay hints should be cancelled")
        XCTAssertTrue(diagnosticsExecuted, "Diagnostics should still execute")
    }

    @MainActor
    func testDefaultDebounceConstants() {
        XCTAssertEqual(LSPViewportScheduler.inlayHintsDebounceMs, 500)
        XCTAssertEqual(LSPViewportScheduler.diagnosticsDebounceMs, 300)
        XCTAssertEqual(LSPViewportScheduler.codeActionsDebounceMs, 400)
    }
}

#endif
