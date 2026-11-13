import AppKit
import Foundation
import Testing
@testable import ClipboardManagerPlugin

/// 剪贴板监控的生命周期代次与轮询间隔（见 issue #775、#423）。
@Suite("剪贴板监控生命周期")
struct ClipboardMonitorLifecycleTests {

    @Test("轮询间隔已缩短到 100ms")
    func pollIntervalIsShortened() {
        // 缩短间隔是为了缩小「两次复制落在同一轮询窗口内」的丢失窗口。
        // 读取 changeCount 极廉价（约 1 微秒），100ms 间隔每秒开销不到 0.02 毫秒。
        #expect(ClipboardMonitorObserver.pollIntervalForTesting <= 0.1)
    }

    @Test("停止监控会让在途处理失效")
    func stoppingMonitoringInvalidatesInFlightWork() {
        var generation = ClipboardLifecycleGeneration()
        let captured = generation.begin()

        #expect(generation.isCurrent(captured))

        generation.stop()

        #expect(generation.isCurrent(captured) == false)
    }

    @Test("反复停止监控每次都会推进代次")
    func repeatedStopsAdvanceGeneration() {
        var generation = ClipboardLifecycleGeneration()
        let before = generation.current

        generation.stop()
        let afterFirst = generation.current
        generation.stop()
        let afterSecond = generation.current

        #expect(afterFirst != before)
        #expect(afterSecond != afterFirst)
    }

    @Test("停止后开始的处理以新代次为准")
    func processingStartedAfterStopUsesNewGeneration() {
        var generation = ClipboardLifecycleGeneration()
        generation.stop()

        let captured = generation.begin()

        // 停止之后才开始的处理是有效的。
        #expect(generation.isCurrent(captured))
    }
}
