import Foundation
import Testing
@testable import ProviderIdleTime

/// `IdleTimeProviding.addObserver` 协议级观察机制的测试。
@Suite("IdleTimeProviding Observation")
struct IdleTimeProvidingObservationTests {

    @Test func defaultPlaceholderReturnsNoopHandleAndNeverFires() async {
        let provider = DefaultIdleTimeProviding()
        let expectation = LockedFlag()

        let handle = provider.addObserver { _ in
            expectation.flag()
        }

        // 占位实现不广播任何事件；回调不应被触发。
        await provider.record(.appBecameActive)
        try? await Task.sleep(for: .milliseconds(20))

        #expect(!expectation.isFlagged)
        handle.cancel()
    }

    @Test func serviceFiresSnapshotChangedAfterRefresh() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("idletime-observer-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = IdleActivityStore(directoryURL: directory)
        let service = IdleTimeService(store: store)
        let events = LockedArray()

        let handle = service.addObserver { event in
            events.append(event)
        }

        // 记录活动会触发快照刷新 → 广播 `.snapshotChanged`。
        await service.record(.appBecameActive, at: Date())
        try await Task.sleep(for: .milliseconds(100))

        #expect(events.count == 1)
        #expect(events.values.first == .snapshotChanged)

        handle.cancel()
        await service.record(.fileSave, at: Date())
        try await Task.sleep(for: .milliseconds(50))
        #expect(events.count == 1, "cancel 后不应再收到通知")
    }
}

/// 线程安全的布尔标记（回调可能在任意线程执行）。
private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flagged = false

    func flag() {
        lock.lock()
        flagged = true
        lock.unlock()
    }

    var isFlagged: Bool {
        lock.lock()
        defer { lock.unlock() }
        return flagged
    }
}

/// 线程安全的事件收集器。
private final class LockedArray: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [IdleTimeProvidingEvent] = []

    func append(_ event: IdleTimeProvidingEvent) {
        lock.lock()
        storage.append(event)
        lock.unlock()
    }

    var values: [IdleTimeProvidingEvent] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }
}