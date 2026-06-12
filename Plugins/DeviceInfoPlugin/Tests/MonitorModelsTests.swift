import Foundation
import Testing
@testable import DeviceInfoPlugin

struct MonitorModelsTests {
    @Test
    func systemMetricsEmpty() {
        let empty = SystemMetrics.empty
        #expect(empty.cpuUsage == .empty)
        #expect(empty.memoryUsage == .empty)
        #expect(empty.network == .empty)
        #expect(empty.disk == .empty)
    }

    @Test
    func resourceUsageEmpty() {
        let empty = ResourceUsage.empty
        #expect(empty.percentage == 0)
        #expect(empty.history.isEmpty)
    }

    @Test
    func networkMetricsEmpty() {
        let empty = NetworkMetrics.empty
        #expect(empty.uploadSpeed == 0)
        #expect(empty.downloadSpeed == 0)
        #expect(empty.uploadHistory.isEmpty)
        #expect(empty.downloadHistory.isEmpty)
    }

    @Test
    func networkMetricsSpeedStrings() {
        let metrics = NetworkMetrics(
            uploadSpeed: 1_048_576,
            downloadSpeed: 5_242_880,
            uploadHistory: [],
            downloadHistory: []
        )
        #expect(metrics.uploadSpeedString.contains("/s"))
        #expect(metrics.downloadSpeedString.contains("/s"))
    }

    @Test
    func diskMetricsEmpty() {
        let empty = DiskMetrics.empty
        #expect(empty.readSpeed == 0)
        #expect(empty.writeSpeed == 0)
    }

    @Test
    func diskMetricsSpeedStrings() {
        let metrics = DiskMetrics(
            readSpeed: 1_048_576,
            writeSpeed: 524_288,
            readHistory: [],
            writeHistory: []
        )
        #expect(metrics.readSpeedString.contains("/s"))
        #expect(metrics.writeSpeedString.contains("/s"))
    }

    @Test
    func processMetricMemoryString() {
        let metric = ProcessMetric(id: 123, name: "Test", icon: nil, cpuUsage: 5.0, memoryUsage: 2_000_000_000)
        #expect(!metric.memoryString.isEmpty)
    }

    @Test
    func processMetricHashable() {
        let a = ProcessMetric(id: 1, name: "A", icon: nil, cpuUsage: 5.0, memoryUsage: 100)
        let b = ProcessMetric(id: 1, name: "A", icon: nil, cpuUsage: 5.0, memoryUsage: 100)
        let set: Set<ProcessMetric> = [a, b]
        #expect(set.count == 1)
    }

    @Test
    func systemMetricsIdentifiable() {
        let m1 = SystemMetrics(
            timestamp: Date(),
            cpuUsage: .empty,
            memoryUsage: .empty,
            network: .empty,
            disk: .empty
        )
        let m2 = SystemMetrics(
            timestamp: Date(),
            cpuUsage: .empty,
            memoryUsage: .empty,
            network: .empty,
            disk: .empty
        )
        #expect(m1.id != m2.id)
    }
}
