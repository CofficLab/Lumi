import Foundation
import Testing
@testable import DeviceMonitorKit

// MARK: - Model Tests

struct MonitorModelsTests {
    @Test
    func systemMetricsEmptyReturnsAllEmptyValues() {
        let metrics = SystemMetrics.empty

        #expect(metrics.cpuUsage.percentage == 0)
        #expect(metrics.cpuUsage.description == "--")
        #expect(metrics.cpuUsage.history.isEmpty)
        #expect(metrics.memoryUsage.percentage == 0)
        #expect(metrics.network.uploadSpeed == 0)
        #expect(metrics.network.downloadSpeed == 0)
        #expect(metrics.disk.readSpeed == 0)
        #expect(metrics.disk.writeSpeed == 0)
        #expect(metrics.timestamp.timeIntervalSinceNow < 1)
    }

    @Test
    func resourceUsageEquatable() {
        let a = ResourceUsage(percentage: 0.5, description: "50%", history: [0.4, 0.5, 0.6])
        let b = ResourceUsage(percentage: 0.5, description: "50%", history: [0.4, 0.5, 0.6])
        let c = ResourceUsage(percentage: 0.7, description: "70%", history: [0.6, 0.7, 0.8])

        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func networkMetricsSpeedFormatting() {
        let metrics = NetworkMetrics(uploadSpeed: 1024, downloadSpeed: 2048, uploadHistory: [], downloadHistory: [])

        #expect(metrics.uploadSpeedString.contains("/s"))
        #expect(metrics.downloadSpeedString.contains("/s"))
    }

    @Test
    func diskMetricsSpeedFormatting() {
        let metrics = DiskMetrics(readSpeed: 1048576, writeSpeed: 524288, readHistory: [], writeHistory: [])

        #expect(metrics.readSpeedString.contains("/s"))
        #expect(metrics.writeSpeedString.contains("/s"))
    }

    @Test
    func processMetricHashableAndIdentifiable() {
        let p1 = ProcessMetric(id: 100, name: "Safari", icon: nil, cpuUsage: 5.0, memoryUsage: 1024 * 1024 * 512)
        let p2 = ProcessMetric(id: 100, name: "Safari", icon: nil, cpuUsage: 5.0, memoryUsage: 1024 * 1024 * 512)
        let p3 = ProcessMetric(id: 200, name: "Chrome", icon: nil, cpuUsage: 10.0, memoryUsage: 1024 * 1024 * 1024)

        #expect(p1 == p2)
        #expect(p1 != p3)
        #expect(p1.id == 100)
        #expect(p1.id != p3.id)
        #expect(p1.memoryString.contains("MB") || p1.memoryString.contains("GB"))
    }

    @Test
    func systemMetricsIdentifiableHasUniqueUUID() {
        let m1 = SystemMetrics.empty
        let m2 = SystemMetrics.empty

        #expect(m1.id != m2.id)
    }
}

// MARK: - CPU Model Tests

struct CPUModelsTests {
    @Test
    func cpuTimeRangeDurations() {
        #expect(CPUTimeRange.hour1.duration == 3600)
        #expect(CPUTimeRange.hour4.duration == 14400)
        #expect(CPUTimeRange.hour24.duration == 86400)
        #expect(CPUTimeRange.month1.duration == 2592000)
    }

    @Test
    func cpuTimeRangeDisplayNamesNonEmpty() {
        for range in CPUTimeRange.allCases {
            #expect(!range.displayName.isEmpty)
            #expect(range.id == range.rawValue)
        }
    }

    @Test
    func cpuTimeRangeCaseIterableCount() {
        #expect(CPUTimeRange.allCases.count == 4)
    }

    @Test
    func cpuDataPointEquatable() {
        let a = CPUDataPoint(timestamp: 1000.0, usage: 45.0)
        let b = CPUDataPoint(timestamp: 1000.0, usage: 45.0)
        let c = CPUDataPoint(timestamp: 1000.0, usage: 50.0)

        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func cpuDataPointIdentifiable() {
        let point = CPUDataPoint(timestamp: 1234.0, usage: 30.0)

        #expect(point.id == 1234.0)
    }

    @Test
    func cpuDataPointCodable() throws {
        let point = CPUDataPoint(timestamp: 1_700_000_000.0, usage: 72.5)

        let data = try JSONEncoder().encode(point)
        let decoded = try JSONDecoder().decode(CPUDataPoint.self, from: data)

        #expect(decoded.timestamp == point.timestamp)
        #expect(decoded.usage == point.usage)
    }
}

// MARK: - Memory Model Tests

struct MemoryModelsTests {
    @Test
    func memoryTimeRangeDurations() {
        #expect(MemoryTimeRange.hour1.duration == 3600)
        #expect(MemoryTimeRange.hour4.duration == 14400)
        #expect(MemoryTimeRange.hour24.duration == 86400)
        #expect(MemoryTimeRange.month1.duration == 2592000)
    }

    @Test
    func memoryTimeRangeDisplayNamesNonEmpty() {
        for range in MemoryTimeRange.allCases {
            #expect(!range.displayName.isEmpty)
            #expect(range.id == range.rawValue)
        }
    }

    @Test
    func memoryTimeRangeCaseIterableCount() {
        #expect(MemoryTimeRange.allCases.count == 4)
    }

    @Test
    func memoryDataPointEquatable() {
        let a = MemoryDataPoint(timestamp: 2000.0, usagePercentage: 60.0, usedBytes: 8 * 1024 * 1024 * 1024)
        let b = MemoryDataPoint(timestamp: 2000.0, usagePercentage: 60.0, usedBytes: 8 * 1024 * 1024 * 1024)
        let c = MemoryDataPoint(timestamp: 2000.0, usagePercentage: 70.0, usedBytes: 8 * 1024 * 1024 * 1024)

        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func memoryDataPointIdentifiable() {
        let point = MemoryDataPoint(timestamp: 5678.0, usagePercentage: 50.0, usedBytes: 4 * 1024 * 1024 * 1024)

        #expect(point.id == 5678.0)
    }

    @Test
    func memoryDataPointCodable() throws {
        let point = MemoryDataPoint(timestamp: 1_700_000_000.0, usagePercentage: 85.2, usedBytes: 16 * 1024 * 1024 * 1024)

        let data = try JSONEncoder().encode(point)
        let decoded = try JSONDecoder().decode(MemoryDataPoint.self, from: data)

        #expect(decoded.timestamp == point.timestamp)
        #expect(decoded.usagePercentage == point.usagePercentage)
        #expect(decoded.usedBytes == point.usedBytes)
    }
}
