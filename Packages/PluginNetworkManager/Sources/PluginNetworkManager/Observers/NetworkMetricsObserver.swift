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
        // 订阅每 tick 一次的原子快照：combineLatest 四个独立属性会让每个
        // 采样发射 4 次，历史每秒被写入 4 个点（#216）。
        // dropFirst() 跳过 @Published 订阅时重放的当前值，避免启动瞬间
        // 把上一次运行遗留的陈旧快照再记一个历史点。
        Self.observeUsageSnapshots(
            NetworkService.shared.$usageSnapshot.dropFirst().eraseToAnyPublisher(),
            record: { down, up in
                NetworkHistoryService.shared.recordDataPoint(down: down, up: up)
            },
            apply: { [weak self] snapshot in
                self?.viewModels.network.applyNetworkUsage(
                    downloadSpeed: snapshot.downloadSpeed,
                    uploadSpeed: snapshot.uploadSpeed,
                    totalDownload: snapshot.totalDownload,
                    totalUpload: snapshot.totalUpload
                )
            }
        )
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

        ProcessMonitorService.shared.$hasPublishedSample
            .sink { [weak self] isReady in
                self?.viewModels.network.updateProcessSnapshotReady(isReady)
            }
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

    /// 把「每个快照记录一个历史点并刷新一次 UI」的接线独立出来，
    /// 便于用受控发布器验证 1:1 关系，而不必构造带定时器/网络请求的完整 observer。
    static func observeUsageSnapshots(
        _ snapshots: AnyPublisher<NetworkUsageSnapshot, Never>,
        record: @escaping (Double, Double) -> Void,
        apply: @escaping (NetworkUsageSnapshot) -> Void
    ) -> AnyCancellable {
        snapshots.sink { snapshot in
            record(snapshot.downloadSpeed, snapshot.uploadSpeed)
            apply(snapshot)
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
