import Foundation
import Testing
@testable import ProviderPerformanceMetrics

struct PerformanceMetricsProviderTests {
    @Test("aggregates percentiles and total events")
    func reportAggregatesEvents() async {
        let provider = DefaultPerformanceMetricsProvider()
        provider.record(operation: "chat.send", stage: "commit", durationMilliseconds: 10)
        provider.record(operation: "chat.send", stage: "commit", durationMilliseconds: 20)
        provider.record(operation: "chat.send", stage: "commit", durationMilliseconds: 100)

        let report = await provider.report()
        guard let summary = report.summaries.first else {
            Issue.record("Expected one summary")
            return
        }
        #expect(summary.count == 3)
        #expect(summary.p50Milliseconds == 20)
        #expect(summary.p95Milliseconds == 100)
        #expect(summary.maxMilliseconds == 100)
    }

    @Test("retains only the configured event window")
    func retentionIsBounded() async {
        let provider = DefaultPerformanceMetricsProvider(maxEventCount: 2)
        provider.record(operation: "test", stage: "one", durationMilliseconds: 1)
        provider.record(operation: "test", stage: "two", durationMilliseconds: 2)
        provider.record(operation: "test", stage: "three", durationMilliseconds: 3)

        let report = await provider.report()
        #expect(report.totalEventCount == 2)
        #expect(report.recentEvents.map(\.durationMilliseconds) == [3, 2])
    }

    @Test("trace records cumulative checkpoints and total")
    func traceRecordsStages() async throws {
        let provider = DefaultPerformanceMetricsProvider()
        let trace = provider.begin(operation: "chat.send", metadata: ["attachments": "false"])
        provider.mark(trace, stage: "committed")
        provider.end(trace)

        let report = await provider.report()
        #expect(report.summaries.map(\.stage) == ["committed", "total"])
        #expect(report.summaries.allSatisfy { $0.operation == "chat.send" })
    }

    @Test("clear removes in-memory metrics and persisted metrics")
    func clearRemovesMetrics() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("metrics-test-\(UUID().uuidString)", isDirectory: true)
        let provider = DefaultPerformanceMetricsProvider(directoryURL: directory)
        provider.record(operation: "test", stage: "one", durationMilliseconds: 1)
        _ = await provider.report()
        provider.clear()

        let report = await provider.report()
        #expect(report.totalEventCount == 0)
    }

    @Test("persists a bounded snapshot for the next provider instance")
    func persistsAcrossInstances() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("metrics-persistence-test-\(UUID().uuidString)", isDirectory: true)
        let provider = DefaultPerformanceMetricsProvider(directoryURL: directory)
        provider.record(operation: "test", stage: "persisted", durationMilliseconds: 12)

        try await Task.sleep(for: .milliseconds(500))

        let restored = DefaultPerformanceMetricsProvider(directoryURL: directory)
        let report = await restored.report()
        #expect(report.totalEventCount == 1)
        #expect(report.summaries.first?.stage == "persisted")
    }
}
