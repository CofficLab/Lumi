import Testing
@testable import PluginDevice

/// CPU 区块进程展示口径的回归测试。
@Suite("ProcessMetric 展示口径")
struct ProcessMetricDisplayTests {

    private func metric(cpuUsage: Double) -> ProcessMetric {
        ProcessMetric(id: 1, name: "Test", icon: nil, cpuUsage: cpuUsage, memoryUsage: 0)
    }

    @Test("直接展示真实 CPU 占用，不按前 N 名归一化")
    func displaysRealCPUUsageWithoutNormalization() {
        // 修复前，前 N 名进程的 CPU 会被归一化成合计 100%；
        // 真实占用应保持原值。
        #expect(metric(cpuUsage: 0.6).formattedCPUUsage == "1%")
        #expect(metric(cpuUsage: 12.4).formattedCPUUsage == "12%")
        #expect(metric(cpuUsage: 120).formattedCPUUsage == "120%")
    }

    @Test("进度条以单核 100% 为满格且不超过 100%")
    func barFractionIsCappedAtOneHundredPercent() {
        #expect(metric(cpuUsage: 50).cpuBarFraction == 0.5)
        #expect(metric(cpuUsage: 120).cpuBarFraction == 1)
        #expect(metric(cpuUsage: -5).cpuBarFraction == 0)
    }
}
