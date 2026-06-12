import Testing
@testable import DeviceInfoPlugin

@MainActor
struct GPUServiceTests {
    @Test
    func memoryUsagePercentageZero() {
        let svc = GPUService()
        #expect(svc.memoryUsagePercentage == 0)
    }

    @Test
    func memoryUsagePercentageCalculated() {
        let svc = GPUService()
        svc.usedMemory = 4_000_000_000
        svc.totalMemory = 8_000_000_000
        #expect(svc.memoryUsagePercentage == 50.0)
    }

    @Test
    func usedMemoryString() {
        let svc = GPUService()
        svc.usedMemory = 4_000_000_000
        #expect(!svc.usedMemoryString.isEmpty)
    }

    @Test
    func totalMemoryString() {
        let svc = GPUService()
        svc.totalMemory = 8_000_000_000
        #expect(!svc.totalMemoryString.isEmpty)
    }
}
