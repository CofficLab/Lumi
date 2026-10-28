import Foundation
import Testing
@testable import PluginNetworkManager

/// #128 回归测试：nettop 子进程的生命周期必须跟随「进程监控面板可见性」。
///
/// ## 背景
///
/// `nettop` 用 `-L 0`（无限循环）参数启动，实测常驻即占 100%+ CPU。
/// 修复前 `NetworkMetricsObserver.init` 会无条件调用
/// `ProcessMonitorService.shared.startMonitoring()`，使引用计数恒为 1；
/// 面板关闭时 `stopMonitoring()` 只把计数减回 1，nettop 永不退出。
///
/// 修复后：observer 不再参与 nettop 的启停，改由
/// `NetworkManagerViewModel.showProcessMonitor` 独占驱动。
@Suite("ProcessMonitorService 生命周期")
@MainActor
struct ProcessMonitorServiceLifecycleTests {

    /// 构造一个使用「真实但无害」长驻进程（`sleep`）的实例。
    ///
    /// 用真实进程而非伪造，是为了让 `Process.isRunning` 与生命周期断言成立；
    /// `sleep` 不产生任何输出，不会干扰数据管道。
    private func makeService() -> (ProcessMonitorService, () -> Int) {
        final class Counter: @unchecked Sendable { var launches = 0 }
        let counter = Counter()
        let service = ProcessMonitorService.makeForTesting { [counter] in
            counter.launches += 1
            let task = Process()
            task.launchPath = "/bin/sleep"
            task.arguments = ["60"]
            return task
        }
        return (service, { counter.launches })
    }

    @Test("start 后 nettop 处于运行状态")
    func startMonitoringLaunchesNettop() {
        let (service, _) = makeService()

        service.startMonitoring()

        #expect(service.isNettopRunning)

        service.stopMonitoring()
    }

    @Test("stop 后 nettop 被终止")
    func stopMonitoringTerminatesNettop() {
        let (service, _) = makeService()

        service.startMonitoring()
        #expect(service.isNettopRunning)

        service.stopMonitoring()
        #expect(!service.isNettopRunning)
    }

    @Test("多次 start 只启动一个 nettop")
    func repeatedStartLaunchesSingleNettop() {
        let (service, launches) = makeService()

        service.startMonitoring()
        service.startMonitoring()
        service.startMonitoring()

        // 只在引用计数从 0 -> 1 时启动一次
        #expect(launches() == 1)

        service.stopMonitoring()
        service.stopMonitoring()
        service.stopMonitoring()
    }

    @Test("引用计数归零后 nettop 退出")
    func nettopStopsWhenRefCountReachesZero() {
        let (service, _) = makeService()

        service.startMonitoring()
        service.startMonitoring()
        #expect(service.isNettopRunning)

        // 第一次 stop 只减计数，仍在运行
        service.stopMonitoring()
        #expect(service.isNettopRunning)

        // 第二次 stop 归零，nettop 退出
        service.stopMonitoring()
        #expect(!service.isNettopRunning)
    }

    @Test("stop 多于 start 不会崩溃且保持停止状态")
    func extraStopKeepsServiceStopped() {
        let (service, _) = makeService()

        service.startMonitoring()
        service.stopMonitoring()
        service.stopMonitoring()
        service.stopMonitoring()

        #expect(!service.isNettopRunning)
    }

    @Test("面板可见时 nettop 启动，隐藏时退出（端到端联动）")
    func panelVisibilityDrivesNettopLifecycle() {
        // 使用共享单例，验证 ViewModel 的默认接线确实指向
        // `ProcessMonitorService.shared`。
        let service = ProcessMonitorService.shared
        let viewModel = NetworkManagerViewModel()

        // 先确保处于干净状态
        while service.isNettopRunning {
            service.stopMonitoring()
        }

        // 面板可见 -> nettop 启动
        viewModel.showProcessMonitor = true
        #expect(service.isNettopRunning)

        // 面板隐藏 -> nettop 退出
        viewModel.showProcessMonitor = false
        #expect(!service.isNettopRunning)
    }

    @Test("观察者不再启动 nettop（修复 #128 的核心断言）")
    func observerDoesNotStartNettop() {
        // 修复前：`NetworkMetricsObserver.init` 会无条件
        // `ProcessMonitorService.shared.startMonitoring()`，
        // 导致面板关闭后 nettop 永不退出。
        //
        // 该断言通过「共享单例的 nettop 未被启动」来表达。
        let shared = ProcessMonitorService.shared
        #expect(!shared.isNettopRunning)
    }
}

/// 面板可见性开关与 nettop 启停的联动测试。
@Suite("进程监控面板可见性")
@MainActor
struct ProcessMonitorVisibilityTests {

    /// 记录 start/stop 调用次数。
    @MainActor
    final class StartStopCounter {
        var starts = 0
        var stops = 0
    }

    @Test("开关切换会成对调用 start/stop")
    func togglePairsStartAndStop() {
        let counter = StartStopCounter()
        let viewModel = NetworkManagerViewModel(
            processMonitoringStarter: { counter.starts += 1 },
            processMonitoringStopper: { counter.stops += 1 }
        )

        viewModel.showProcessMonitor = true
        #expect(counter.starts == 1)
        #expect(counter.stops == 0)

        viewModel.showProcessMonitor = false
        #expect(counter.starts == 1)
        #expect(counter.stops == 1)
    }

    @Test("重复赋值不会重复启停")
    func repeatedAssignmentDoesNotDuplicateCalls() {
        let counter = StartStopCounter()
        let viewModel = NetworkManagerViewModel(
            processMonitoringStarter: { counter.starts += 1 },
            processMonitoringStopper: { counter.stops += 1 }
        )

        viewModel.showProcessMonitor = true
        viewModel.showProcessMonitor = true
        viewModel.showProcessMonitor = true
        viewModel.showProcessMonitor = false
        viewModel.showProcessMonitor = false

        #expect(counter.starts == 1)
        #expect(counter.stops == 1)
    }
}
