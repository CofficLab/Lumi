import Testing
@testable import DeviceInfoPlugin

struct ProcessServiceTests {
    @Test
    func cpuPercentCalculation() {
        // 10_000_000 ticks = 1 second of CPU time
        let pct = ProcessService.cpuPercent(forProcessTimeDelta: 10_000_000, elapsedSeconds: 1.0)
        #expect(pct == 100.0)
    }

    @Test
    func cpuPercentZeroDelta() {
        let pct = ProcessService.cpuPercent(forProcessTimeDelta: 0, elapsedSeconds: 1.0)
        #expect(pct == 0)
    }

    @Test
    func cpuPercentZeroTime() {
        let pct = ProcessService.cpuPercent(forProcessTimeDelta: 10_000_000, elapsedSeconds: 0)
        #expect(pct == 0)
    }

    @Test
    func cpuPercentPartialUsage() {
        // 5_000_000 ticks in 1 second = 50%
        let pct = ProcessService.cpuPercent(forProcessTimeDelta: 5_000_000, elapsedSeconds: 1.0)
        #expect(pct == 50.0)
    }

    @Test
    func cpuPercentMultiCore() {
        // 20_000_000 ticks in 1 second = 200% (2 cores)
        let pct = ProcessService.cpuPercent(forProcessTimeDelta: 20_000_000, elapsedSeconds: 1.0)
        #expect(pct == 200.0)
    }
}
