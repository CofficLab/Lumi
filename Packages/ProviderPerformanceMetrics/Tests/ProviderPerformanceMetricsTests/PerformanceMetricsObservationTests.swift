import Foundation
import Testing
@testable import ProviderPerformanceMetrics

/// `PerformanceMetricsProviding.addObserver` 观察机制的测试。
@Suite("PerformanceMetrics Observation")
struct PerformanceMetricsObservationTests {

    @Test func recordFiresDidRecordForEachEvent() async throws {
        let provider = DefaultPerformanceMetricsProvider()
        let collector = EventCollector()

        let handle = provider.addObserver { event in
            collector.append(event)
        }

        provider.record(operation: "chat.send", stage: "commit", durationMilliseconds: 10)
        provider.record(operation: "chat.send", stage: "commit", durationMilliseconds: 20)

        try await Task.sleep(for: .milliseconds(20))

        let events = collector.values
        #expect(events.count == 2)
        if case .didRecord(let recorded) = events[0] {
            #expect(recorded.operation == "chat.send")
            #expect(recorded.stage == "commit")
            #expect(recorded.durationMilliseconds == 10)
        } else {
            Issue.record("Expected didRecord event, got \(events[0])")
        }

        handle.cancel()
    }

    @Test func clearFiresDidClear() async throws {
        let provider = DefaultPerformanceMetricsProvider()
        let collector = EventCollector()

        let handle = provider.addObserver { event in
            collector.append(event)
        }
        provider.record(operation: "test", stage: "one", durationMilliseconds: 1)
        provider.clear()

        try await Task.sleep(for: .milliseconds(20))

        let events = collector.values
        #expect(events.count == 2)
        if case .didClear = events[1] {
            // OK
        } else {
            Issue.record("Expected didClear event, got \(events[1])")
        }
        handle.cancel()
    }

    @Test func cancelledHandleStopsReceiving() async throws {
        let provider = DefaultPerformanceMetricsProvider()
        let collector = EventCollector()

        let handle = provider.addObserver { event in
            collector.append(event)
        }
        provider.record(operation: "test", stage: "before", durationMilliseconds: 1)
        handle.cancel()
        provider.record(operation: "test", stage: "after", durationMilliseconds: 2)

        try await Task.sleep(for: .milliseconds(20))
        #expect(collector.values.count == 1)
    }

    @Test func observerCanReenterProviderWithoutDeadlock() async throws {
        let provider = DefaultPerformanceMetricsProvider()
        let collector = EventCollector()
        let reentryGuard = ReentryGuard()

        // 回调内再次调用 provider（仅一次）——验证锁外通知不会死锁，
        // 也不会因 re-enter record 无限递归（使用 guard 限制嵌套次数）。
        let handle = provider.addObserver { [weak provider] event in
            guard case .didRecord = event else { return }
            if reentryGuard.allowOnce() {
                provider?.record(operation: "nested", stage: "reentry", durationMilliseconds: 1)
            }
            collector.append(event)
        }
        provider.record(operation: "outer", stage: "entry", durationMilliseconds: 1)

        try await Task.sleep(for: .milliseconds(50))
        #expect(collector.values.count == 2, "外层 + 一次嵌套")
        handle.cancel()
        _ = reentryGuard
    }
}

/// 只允许一次嵌套重入的守卫。
private final class ReentryGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var used = false

    func allowOnce() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if used { return false }
        used = true
        return true
    }
}

/// 线程安全的事件收集器（回调可能在任意线程执行）。
private final class EventCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [PerformanceMetricsProvidingEvent] = []

    func append(_ event: PerformanceMetricsProvidingEvent) {
        lock.lock()
        storage.append(event)
        lock.unlock()
    }

    var values: [PerformanceMetricsProvidingEvent] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}