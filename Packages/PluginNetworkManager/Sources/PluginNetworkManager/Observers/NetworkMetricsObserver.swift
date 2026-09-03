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

        ProcessMonitorService.shared.startMonitoring()
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
        ProcessMonitorService.shared.stopMonitoring()
    }
}
