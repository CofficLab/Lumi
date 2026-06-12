import Foundation
import Testing
@testable import DeviceInfoPlugin

struct GPUModelsTests {
    @Test
    func gpuTimeRangeAllCases() {
        #expect(GPUTimeRange.allCases.count == 4)
    }

    @Test
    func gpuTimeRangeDurations() {
        #expect(GPUTimeRange.hour1.duration == 3600)
        #expect(GPUTimeRange.hour4.duration == 14400)
        #expect(GPUTimeRange.hour24.duration == 86400)
        #expect(GPUTimeRange.month1.duration == 2592000)
    }

    @Test
    func gpuDataPointIdentifiable() {
        let point = GPUDataPoint(timestamp: 200, usage: 33.3)
        #expect(point.id == 200)
    }

    @Test
    func gpuDataPointCodable() throws {
        let point = GPUDataPoint(timestamp: 300, usage: 80.0)
        let data = try JSONEncoder().encode(point)
        let decoded = try JSONDecoder().decode(GPUDataPoint.self, from: data)
        #expect(decoded == point)
    }

    @Test
    func gpuReadingEmptyDefaults() {
        let empty = GPUReading.empty
        #expect(empty.utilization == 0)
        #expect(empty.rendererUtilization == 0)
        #expect(empty.tilerUtilization == 0)
        #expect(empty.usedMemory == 0)
        #expect(empty.totalMemory == 0)
        #expect(empty.temperature == 0)
        #expect(empty.modelName == "")
    }
}
