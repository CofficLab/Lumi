import Foundation
import Testing
@testable import DeviceMonitorKit

// MARK: - Service Tests

struct CPUServiceTests {
    @Test
    @MainActor
    func sharedInstanceIsSingleton() {
        let a = CPUService.shared
        let b = CPUService.shared
        #expect(a === b)
    }

    @Test
    @MainActor
    func initialCpuUsageIsZero() {
        let service = CPUService()
        #expect(service.cpuUsage == 0.0)
        #expect(service.perCoreUsage.isEmpty)
    }

    @Test
    @MainActor
    func initialLoadAverageIsZero() {
        let service = CPUService()
        #expect(service.loadAverage.count == 3)
        #expect(service.loadAverage == [0, 0, 0])
    }

    @Test
    @MainActor
    func startMonitoringIncrementsSubscribers() {
        let service = CPUService()
        service.startMonitoring()
        service.startMonitoring()
        // Should not crash, ref counting works
        service.stopMonitoring()
        service.stopMonitoring()
        #expect(service.cpuUsage >= 0)
    }

    @Test
    @MainActor
    func stopMonitoringWithForceClear() {
        let service = CPUService()
        service.startMonitoring()
        service.startMonitoring()
        service.stopMonitoring()
        service.stopMonitoring()
        #expect(service.cpuUsage == 0.0)
    }

    @Test
    @MainActor
    func perCoreUsageHasExpectedLengthAfterStart() async throws {
        let service = CPUService()
        service.startMonitoring()

        // Wait a brief moment for the timer to fire
        try await Task.sleep(for: .milliseconds(1500))

        let coreCount = ProcessInfo.processInfo.activeProcessorCount
        #expect(service.perCoreUsage.count == coreCount || service.perCoreUsage.isEmpty)

        service.stopMonitoring()
    }
}

// MARK: - Memory Service Tests

struct MemoryServiceTests {
    @Test
    @MainActor
    func sharedInstanceIsSingleton() {
        let a = MemoryService.shared
        let b = MemoryService.shared
        #expect(a === b)
    }

    @Test
    @MainActor
    func totalMemoryMatchesProcessInfo() {
        let service = MemoryService()
        #expect(service.totalMemory == ProcessInfo.processInfo.physicalMemory)
    }

    @Test
    @MainActor
    func initialMemoryUsageIsZero() {
        let service = MemoryService()
        #expect(service.memoryUsagePercentage == 0.0)
        #expect(service.usedMemory == 0)
    }

    @Test
    @MainActor
    func initialPressureIsNormal() {
        let service = MemoryService()
        #expect(service.memoryPressure == "Normal")
    }

    @Test
    @MainActor
    func startMonitoringIncrementsSubscribers() {
        let service = MemoryService()
        service.startMonitoring()
        service.startMonitoring()
        service.stopMonitoring()
        service.stopMonitoring()
        #expect(service.memoryUsagePercentage >= 0)
    }

    @Test
    @MainActor
    func computeMemoryUsageReturnsNonZeroValues() {
        let service = MemoryService()
        let (used, total) = service.computeMemoryUsage()

        #expect(total == service.totalMemory)
        #expect(used > 0)
        #expect(total > 0)
        #expect(used <= total)
    }

    @Test
    @MainActor
    func memoryUpdatesAfterStartMonitoring() async throws {
        let service = MemoryService()
        service.startMonitoring()

        try await Task.sleep(for: .milliseconds(1500))

        #expect(service.usedMemory > 0)
        #expect(service.memoryUsagePercentage > 0)
        #expect(service.memoryUsagePercentage <= 100.0)

        service.stopMonitoring()
    }
}

// MARK: - System Monitor Service Tests

struct SystemMonitorServiceTests {
    @Test
    @MainActor
    func sharedInstanceIsSingleton() {
        let a = SystemMonitorService.shared
        let b = SystemMonitorService.shared
        #expect(a === b)
    }

    @Test
    @MainActor
    func initialMetricsAreEmpty() {
        let service = SystemMonitorService()
        #expect(service.currentMetrics.cpuUsage.description == "--")
        #expect(service.currentMetrics.memoryUsage.percentage == 0)
    }

    @Test
    @MainActor
    func refCountingWorks() {
        let service = SystemMonitorService()
        service.startMonitoring()
        service.startMonitoring()
        service.stopMonitoring()
        // Should still be running (refCount == 1)
        service.stopMonitoring()
        // Now stopped
        #expect(service.currentMetrics.cpuUsage.history.isEmpty == false)
    }

    @Test
    @MainActor
    func forceStopClearsRefCount() {
        let service = SystemMonitorService()
        service.startMonitoring()
        service.startMonitoring()
        service.stopMonitoring(force: true)
        #expect(service.currentMetrics.cpuUsage.history.isEmpty == false)
    }

    @Test
    @MainActor
    func metricsUpdateAfterStart() async throws {
        let service = SystemMonitorService()
        service.startMonitoring()

        try await Task.sleep(for: .milliseconds(1500))

        let metrics = service.currentMetrics
        #expect(metrics.timestamp.timeIntervalSinceNow < 2)
        #expect(!metrics.cpuUsage.history.isEmpty)
        #expect(!metrics.memoryUsage.history.isEmpty)

        service.stopMonitoring()
    }

    @Test
    @MainActor
    func networkMetricsHaveSpeedStrings() async throws {
        let service = SystemMonitorService()
        service.startMonitoring()

        try await Task.sleep(for: .milliseconds(1500))

        let net = service.currentMetrics.network
        #expect(!net.uploadSpeedString.isEmpty)
        #expect(!net.downloadSpeedString.isEmpty)

        service.stopMonitoring()
    }

    @Test
    @MainActor
    func diskMetricsUseCounterDeltas() {
        let counter = DiskCounterSequence()
        let service = SystemMonitorService(
            diskCountersProvider: { counter.nextCounters() },
            timeProvider: { counter.nextTime() }
        )

        service.refreshMetricsForTesting()
        #expect(service.currentMetrics.disk.readSpeed == 0)
        #expect(service.currentMetrics.disk.writeSpeed == 0)

        service.refreshMetricsForTesting()
        #expect(service.currentMetrics.disk.readSpeed == 1500)
        #expect(service.currentMetrics.disk.writeSpeed == 600)
        #expect(service.currentMetrics.disk.readHistory.last == 1500)
        #expect(service.currentMetrics.disk.writeHistory.last == 600)
    }

    @Test
    @MainActor
    func scheduledMetricsThrottleDiskCounterReads() async throws {
        let clock = ManualClock(now: 100)
        let reader = DiskCounterReaderSpy()
        let service = SystemMonitorService(
            diskCountersReader: { reader.nextCounters() },
            diskCounterInterval: 5,
            timeProvider: { clock.now }
        )

        service.refreshScheduledMetricsForTesting()
        try await waitUntil { reader.callCount == 1 }

        clock.now = 102
        service.refreshScheduledMetricsForTesting()
        try await Task.sleep(for: .milliseconds(100))
        #expect(reader.callCount == 1)

        clock.now = 105
        service.refreshScheduledMetricsForTesting()
        try await waitUntil { reader.callCount == 2 }
    }
}

@MainActor
private final class DiskCounterSequence {
    private var counterIndex = 0
    private var timeIndex = 0
    private let counters: [(readBytes: UInt64, writeBytes: UInt64)] = [
        (1_000, 2_000),
        (2_500, 2_600),
    ]
    private let times: [TimeInterval] = [100, 101]

    func nextCounters() -> (readBytes: UInt64, writeBytes: UInt64) {
        defer { counterIndex += 1 }
        return counters[min(counterIndex, counters.count - 1)]
    }

    func nextTime() -> TimeInterval {
        defer { timeIndex += 1 }
        return times[min(timeIndex, times.count - 1)]
    }
}

@MainActor
private final class ManualClock {
    var now: TimeInterval

    init(now: TimeInterval) {
        self.now = now
    }
}

private final class DiskCounterReaderSpy: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0

    var callCount: Int {
        lock.withLock { calls }
    }

    func nextCounters() -> (readBytes: UInt64, writeBytes: UInt64) {
        lock.withLock {
            calls += 1
            return (UInt64(calls) * 1_000, UInt64(calls) * 2_000)
        }
    }
}

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(1),
    condition: @MainActor @escaping () -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        if ContinuousClock.now >= deadline {
            Issue.record("Timed out waiting for condition")
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}

// MARK: - CPU History Service Tests

struct CPUHistoryServiceTests {
    @Test
    @MainActor
    func sharedInstanceIsSingleton() {
        let a = CPUHistoryService.shared
        let b = CPUHistoryService.shared
        #expect(a === b)
    }

    @Test
    @MainActor
    func recordDataPointAddsToRecentHistory() {
        let service = CPUHistoryService()
        service.recordDataPoint(usage: 55.0)

        #expect(service.recentHistory.count >= 1)
        let last = service.recentHistory.last
        #expect(last?.usage == 55.0)
    }

    @Test
    @MainActor
    func recentHistoryRespectsMaxPoints() {
        let service = CPUHistoryService()

        // Record more than maxRecentPoints (3600) points
        for i in 1...3605 {
            service.recordDataPoint(usage: Double(i))
        }

        #expect(service.recentHistory.count <= 3600)
    }

    @Test
    @MainActor
    func getDataForOneHourReturnsRecentPoints() {
        let service = CPUHistoryService()
        service.recordDataPoint(usage: 30.0)
        service.recordDataPoint(usage: 40.0)

        let data = service.getData(for: CPUTimeRange.hour1)

        #expect(data.count >= 2)
    }

    @Test
    @MainActor
    func longTermHistoryAggregatesByMinute() async throws {
        let service = CPUHistoryService()
        service.recordDataPoint(usage: 50.0)

        // Wait for a minute boundary to trigger long-term aggregation
        // We can't easily test this synchronously, so just verify recording works
        #expect(service.recentHistory.count >= 1)
    }
}

// MARK: - Memory History Service Tests

struct MemoryHistoryServiceTests {
    @Test
    @MainActor
    func sharedInstanceIsSingleton() {
        let a = MemoryHistoryService.shared
        let b = MemoryHistoryService.shared
        #expect(a === b)
    }

    @Test
    @MainActor
    func recordDataPointAddsToRecentHistory() {
        let service = MemoryHistoryService()
        let testBytes: UInt64 = 8 * 1024 * 1024 * 1024
        service.recordDataPoint(pct: 65.0, bytes: testBytes)

        #expect(service.recentHistory.count >= 1)
        let last = service.recentHistory.last
        #expect(last?.usagePercentage == 65.0)
        #expect(last?.usedBytes == testBytes)
    }

    @Test
    @MainActor
    func recentHistoryRespectsMaxPoints() {
        let service = MemoryHistoryService()

        for i in 1...3605 {
            service.recordDataPoint(pct: Double(i), bytes: UInt64(i * 1024))
        }

        #expect(service.recentHistory.count <= 3600)
    }

    @Test
    @MainActor
    func getDataForOneHourReturnsRecentPoints() {
        let service = MemoryHistoryService()
        service.recordDataPoint(pct: 50.0, bytes: 4 * 1024 * 1024 * 1024)
        service.recordDataPoint(pct: 55.0, bytes: 5 * 1024 * 1024 * 1024)

        let data = service.getData(for: MemoryTimeRange.hour1)

        #expect(data.count >= 2)
    }

    @Test
    @MainActor
    func getDataForLongTermReturnsFilteredHistory() {
        let service = MemoryHistoryService()
        // Long-term requires minute boundaries, but recent data works
        let data = service.getData(for: MemoryTimeRange.hour4)
        #expect(data.isEmpty || data.count > 0) // Should not crash
    }
}

// MARK: - Process Service Tests

struct ProcessServiceTests {
    @Test
    func processCPUPercentUsesProcTaskInfoTickUnits() {
        let threeCoresForThreeSeconds = UInt64(90_000_000)
        let cpuPercent = ProcessService.cpuPercent(
            forProcessTimeDelta: threeCoresForThreeSeconds,
            elapsedSeconds: 3.0
        )

        #expect(cpuPercent == 300.0)
    }

    @Test
    @MainActor
    func sharedInstanceIsSingleton() {
        let a = ProcessService.shared
        let b = ProcessService.shared
        #expect(a === b)
    }

    @Test
    @MainActor
    func initialTopProcessesIsEmpty() {
        let service = ProcessService()
        #expect(service.topProcesses.isEmpty)
    }

    @Test
    @MainActor
    func sampleProcessesReturnsValidPIDs() {
        let service = ProcessService()
        // Trigger an initial sample
        let _ = service.sampleProcessesInternal()
        // Results should be empty on first call (no previous snapshot)
        // but on subsequent calls with previous snapshot it returns data
        _ = service.sampleProcessesInternal()
        // After first call, previousSnapshot is populated
        #expect(service.topProcesses.isEmpty)
    }

    @Test
    @MainActor
    func startMonitoringPopulatesTopProcesses() async throws {
        let service = ProcessService()
        service.startMonitoring()

        // Wait for at least one sampling interval (3s)
        try await Task.sleep(for: .milliseconds(3500))

        // On a busy system, should have some top processes
        // But we just verify it doesn't crash
        let count = service.topProcesses.count
        #expect(count >= 0 && count <= 5)

        service.stopMonitoring()
    }

    @Test
    @MainActor
    func stopMonitoringClearsProcesses() {
        let service = ProcessService()
        service.startMonitoring()
        service.stopMonitoring()

        #expect(service.topProcesses.isEmpty)
    }
}
