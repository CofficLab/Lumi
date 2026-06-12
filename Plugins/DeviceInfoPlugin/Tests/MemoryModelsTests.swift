import Foundation
import Testing
@testable import DeviceInfoPlugin

struct MemoryModelsTests {
    @Test
    func memoryTimeRangeAllCases() {
        #expect(MemoryTimeRange.allCases.count == 4)
    }

    @Test
    func memoryTimeRangeDurations() {
        #expect(MemoryTimeRange.hour1.duration == 3600)
        #expect(MemoryTimeRange.hour4.duration == 14400)
        #expect(MemoryTimeRange.hour24.duration == 86400)
        #expect(MemoryTimeRange.month1.duration == 2592000)
    }

    @Test
    func memoryDataPointIdentifiable() {
        let point = MemoryDataPoint(timestamp: 100, usagePercentage: 55.0, usedBytes: 8_000_000_000)
        #expect(point.id == 100)
        #expect(point.usagePercentage == 55.0)
        #expect(point.usedBytes == 8_000_000_000)
    }

    @Test
    func memoryDataPointCodable() throws {
        let point = MemoryDataPoint(timestamp: 500, usagePercentage: 75.0, usedBytes: 12_000_000_000)
        let data = try JSONEncoder().encode(point)
        let decoded = try JSONDecoder().decode(MemoryDataPoint.self, from: data)
        #expect(decoded == point)
    }
}
