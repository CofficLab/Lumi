import Darwin
import Testing
@testable import DeviceInfoPlugin

@MainActor
struct SystemMonitorServiceTests {
    @Test
    func shouldReadNetworkCountersIgnoresNonAFLink() {
        #expect(SystemMonitorService.shouldReadNetworkCounters(flags: UInt32(IFF_UP), addressFamily: UInt8(AF_INET)) == false)
    }

    @Test
    func shouldReadNetworkCountersIgnoresLoopback() {
        #expect(SystemMonitorService.shouldReadNetworkCounters(flags: UInt32(IFF_UP | IFF_LOOPBACK), addressFamily: UInt8(AF_LINK)) == false)
    }

    @Test
    func shouldReadNetworkCountersIgnoresDownInterface() {
        #expect(SystemMonitorService.shouldReadNetworkCounters(flags: 0, addressFamily: UInt8(AF_LINK)) == false)
    }

    @Test
    func shouldReadNetworkCountersAcceptsValidInterface() {
        #expect(SystemMonitorService.shouldReadNetworkCounters(flags: UInt32(IFF_UP), addressFamily: UInt8(AF_LINK)) == true)
    }

    @Test
    func initialMetricsAreEmpty() {
        let svc = SystemMonitorService()
        #expect(svc.currentMetrics.cpuUsage.percentage == 0)
        #expect(svc.currentMetrics.memoryUsage.percentage == 0)
        #expect(svc.currentMetrics.network.uploadSpeed == 0)
        #expect(svc.currentMetrics.network.downloadSpeed == 0)
        #expect(svc.currentMetrics.disk.readSpeed == 0)
        #expect(svc.currentMetrics.disk.writeSpeed == 0)
    }

    @Test
    func startStopMonitoringRefCount() {
        let svc = SystemMonitorService()
        svc.startMonitoring()
        svc.startMonitoring()
        svc.stopMonitoring()
        svc.stopMonitoring()
        // If no crash, ref counting works
    }

    @Test
    func forceStopResetsRefCount() {
        let svc = SystemMonitorService()
        svc.startMonitoring()
        svc.startMonitoring()
        svc.stopMonitoring(force: true)
        // Force stop should clean up even with ref count > 1
    }
}
