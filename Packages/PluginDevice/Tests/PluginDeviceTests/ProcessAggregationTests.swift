import Foundation
import Testing
@testable import PluginDevice

/// CPU 进程展示口径的回归测试：同名聚合、份数标注、本应用标注与前 5 截取。
@MainActor
@Suite("CPU 进程聚合展示")
struct ProcessAggregationTests {

    private func sample(
        pid: Int32,
        name: String,
        cpu: Double,
        icon: String? = nil,
        memory: Int64 = 0
    ) -> ProcessService.CPUSample {
        ProcessService.CPUSample(
            pid: pid,
            name: name,
            icon: icon,
            cpuUsage: cpu,
            memoryUsage: memory
        )
    }

    @Test("同名多进程合并为一条并标注份数，本应用组单独标记")
    func aggregatesSameNameProcessesAndMarksSelf() throws {
        let metrics = ProcessService.aggregate([
            sample(pid: 10, name: "Google Chrome Helper (Renderer)", cpu: 3.2),
            sample(pid: 11, name: "Google Chrome Helper (Renderer)", cpu: 4.8),
            sample(pid: 42, name: "Lumi", cpu: 1.5),
        ], selfPID: 42)

        #expect(metrics.count == 2)

        let chrome = try #require(metrics.first { $0.name == "Google Chrome Helper (Renderer)" })
        #expect(chrome.instanceCount == 2)
        // 聚合后 CPU 相加，且不因合并而丢弃任何一份。
        #expect(abs(chrome.cpuUsage - 8.0) < 0.0001)
        #expect(!chrome.isCurrentApp)

        let lumi = try #require(metrics.first { $0.name == "Lumi" })
        #expect(lumi.isCurrentApp)
        #expect(lumi.instanceCount == 1)
    }

    @Test("不同完整名称的进程不会被误合并")
    func keepsDistinctNamesSeparate() {
        let metrics = ProcessService.aggregate([
            sample(pid: 100, name: "com.apple.WebKit.WebContent", cpu: 2),
            sample(pid: 101, name: "com.apple.WebKit.Networking", cpu: 1),
        ], selfPID: 999)

        #expect(Set(metrics.map(\.name)) == [
            "com.apple.WebKit.WebContent",
            "com.apple.WebKit.Networking",
        ])
        #expect(metrics.allSatisfy { $0.instanceCount == 1 })
    }

    @Test("主弹窗只展示前 5 条，其余保留在完整列表")
    func previewLimitsToFive() {
        let viewModel = CPUManagerViewModel()
        viewModel.apply(topProcesses: (1 ... 7).map { index in
            ProcessMetric(
                id: Int32(index),
                name: "Process \(index)",
                icon: nil,
                cpuUsage: Double(8 - index),
                memoryUsage: 0
            )
        })

        #expect(viewModel.topProcesses.count == 7)
        #expect(viewModel.topProcessesPreview.count == 5)
        #expect(viewModel.topProcessesPreview.first?.name == "Process 1")
    }

    @Test("CPU 采样间隔与网络区块统一为 1 秒")
    func samplingIntervalMatchesNetworkBlock() {
        #expect(ProcessService.samplingInterval == 1.0)
    }
}
