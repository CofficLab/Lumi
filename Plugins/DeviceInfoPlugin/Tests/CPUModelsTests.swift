import Foundation
import Testing
@testable import DeviceInfoPlugin

struct CPUModelsTests {
    @Test
    func cpuTimeRangeAllCases() {
        #expect(CPUTimeRange.allCases.count == 4)
    }

    @Test
    func cpuTimeRangeDurations() {
        #expect(CPUTimeRange.hour1.duration == 3600)
        #expect(CPUTimeRange.hour4.duration == 14400)
        #expect(CPUTimeRange.hour24.duration == 86400)
        #expect(CPUTimeRange.month1.duration == 2592000)
    }

    @Test
    func cpuTimeRangeId() {
        #expect(CPUTimeRange.hour1.id == "hour1")
        #expect(CPUTimeRange.month1.id == "month1")
    }

    @Test
    func cpuDataPointIdentifiable() {
        let point = CPUDataPoint(timestamp: 100, usage: 45.5)
        #expect(point.id == 100)
        #expect(point.usage == 45.5)
    }

    @Test
    func cpuDataPointCodable() throws {
        let point = CPUDataPoint(timestamp: 500, usage: 75.0)
        let data = try JSONEncoder().encode(point)
        let decoded = try JSONDecoder().decode(CPUDataPoint.self, from: data)
        #expect(decoded == point)
    }

    @Test
    func cpuDataPointEquatable() {
        let a = CPUDataPoint(timestamp: 1, usage: 50)
        let b = CPUDataPoint(timestamp: 1, usage: 50)
        let c = CPUDataPoint(timestamp: 1, usage: 60)
        #expect(a == b)
        #expect(a != c)
    }
}
