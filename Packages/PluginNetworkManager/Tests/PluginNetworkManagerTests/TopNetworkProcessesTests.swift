import Foundation
import Testing
@testable import PluginNetworkManager

/// 主菜单栏弹窗网络区块内联进程列表的回归测试。
@MainActor
@Suite("网络区块内联进程列表")
struct TopNetworkProcessesTests {

    private func makeProcess(id: Int, name: String, download: Double, upload: Double) -> NetworkProcess {
        NetworkProcess(
            id: id,
            name: name,
            icon: nil,
            downloadSpeed: download,
            uploadSpeed: upload,
            timestamp: Date()
        )
    }

    private func makeViewModel(
        counter: ProcessMonitorVisibilityTests.StartStopCounter = .init()
    ) -> NetworkManagerViewModel {
        NetworkManagerViewModel(
            processMonitoringStarter: { counter.starts += 1 },
            processMonitoringStopper: { counter.stops += 1 }
        )
    }

    @Test("按总速率降序，最多 5 条，并排除零值与显示为 0 的速率")
    func sortsLimitsAndFiltersZeroSpeed() {
        let viewModel = makeViewModel()
        viewModel.updateProcesses([
            makeProcess(id: 1, name: "Idle", download: 0, upload: 0),
            makeProcess(id: 2, name: "A", download: 100, upload: 0),
            makeProcess(id: 3, name: "B", download: 0, upload: 500),
            makeProcess(id: 4, name: "C", download: 300, upload: 0),
            makeProcess(id: 5, name: "D", download: 200, upload: 0),
            makeProcess(id: 6, name: "E", download: 50, upload: 0),
            makeProcess(id: 7, name: "F", download: 10, upload: 0),
            // 移动平均后可能出现的亚字节速率，格式化结果为 0B/s，不应进入列表。
            makeProcess(id: 8, name: "SubByte", download: 0.2, upload: 0),
        ])

        #expect(viewModel.topNetworkProcesses.map(\.name) == ["B", "C", "D", "A", "E"])
    }

    @Test("速率格式化随量级切换单位与小数位")
    func rateFormattingSwitchesUnitsAndDecimals() {
        #expect(SpeedFormatter.formatForStatusBar(512) == "512B/s")
        #expect(SpeedFormatter.formatForStatusBar(16 * 1024) == "16KB/s")
        #expect(SpeedFormatter.formatForStatusBar(1.5 * 1024 * 1024) == "1.5MB/s")
        #expect(SpeedFormatter.formatForStatusBar(2 * 1024 * 1024 * 1024) == "2.0GB/s")
    }

    @Test("内联列表与详情浮层同时可见时不会提前停止监控")
    func concurrentVisibilityKeepsMonitoring() {
        let counter = ProcessMonitorVisibilityTests.StartStopCounter()
        let viewModel = makeViewModel(counter: counter)

        viewModel.acquireProcessMonitor()  // 主弹窗内联列表可见
        viewModel.acquireProcessMonitor()  // 悬停详情浮层可见
        #expect(counter.starts == 1)

        viewModel.releaseProcessMonitor()  // 详情浮层关闭，内联列表仍在
        #expect(counter.stops == 0)

        viewModel.releaseProcessMonitor()  // 主弹窗关闭
        #expect(counter.stops == 1)
    }
}
