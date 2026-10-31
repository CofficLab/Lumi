import Combine
import Foundation

@MainActor
final class NetworkMetricsObserver {
    private var cancellables = Set<AnyCancellable>()
    private var slowStatsTimer: Timer?
    private var autosaveTimer: Timer?
    private let viewModels: NetworkPluginViewModels

    init(viewModels: NetworkPluginViewModels) {
        self.viewModels = viewModels
        NetworkService.shared.startMonitoring()
        NetworkService.shared.$downloadSpeed
            .combineLatest(
                NetworkService.shared.$uploadSpeed,
                NetworkService.shared.$totalDownload,
                NetworkService.shared.$totalUpload
            )
            .sink { [weak self] down, up, totalDown, totalUp in
                NetworkHistoryService.shared.recordDataPoint(down: down, up: up)
                self?.viewModels.network.applyNetworkUsage(
                    downloadSpeed: down,
                    uploadSpeed: up,
                    totalDownload: totalDown,
                    totalUpload: totalUp
                )
            }
            .store(in: &cancellables)

        // 注意：**不要**在这里调用 `ProcessMonitorService.shared.startMonitoring()`。
        //
        // `nettop` 子进程使用 `-L 0`（无限循环）参数，实测常驻即占 100%+ CPU。
        // 它只应在「进程监控面板可见」时运行，由
        // `NetworkManagerViewModel.showProcessMonitor` 的开关驱动
        // （面板 `onAppear` 置 true、`onDisappear` 置 false）。
        //
        // 此前 observer 在 init 里无条件 startMonitoring()，使引用计数恒为 1，
        // 面板关闭后 nettop 永不退出。
        ProcessMonitorService.shared.$processes
            .sink { [weak self] processes in self?.viewModels.network.updateProcesses(processes) }
            .store(in: &cancellables)

        NetworkHistoryService.shared.$recentHistory
            .combineLatest(NetworkHistoryService.shared.$longTermHistory)
            .sink { [weak self] recent, longTerm in
                self?.viewModels.history.apply(recent: recent, longTerm: longTerm)
            }
            .store(in: &cancellables)

        refreshSlowStats()
        slowStatsTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshSlowStats()
            }
        }
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor in
                NetworkHistoryService.shared.saveHistory()
            }
        }
    }

    private func refreshSlowStats() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let (ssid, rssi) = await NetworkService.shared.getWifiInfo()
            let latency = await NetworkService.shared.ping()
            viewModels.network.applySlowStats(
                wifiSSID: ssid,
                wifiSignalStrength: rssi,
                ping: latency,
                localIP: NetworkService.shared.getLocalIP(),
                publicIP: nil
            )
            await viewModels.network.refreshPublicIPIfNeeded()
        }
    }

    func cancel() {
        slowStatsTimer?.invalidate()
        slowStatsTimer = nil
        autosaveTimer?.invalidate()
        autosaveTimer = nil
        cancellables.removeAll()
        NetworkService.shared.stopMonitoring()
        // 不在此处调用 `ProcessMonitorService.shared.stopMonitoring()`：
        // 本 observer 从未 start 过（nettop 由面板可见性驱动），
        // 多减一次会破坏 `ProcessMonitorService` 的引用计数。
    }
}
