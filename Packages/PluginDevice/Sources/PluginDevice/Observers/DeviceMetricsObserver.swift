import Combine
import Foundation

/// 将设备服务的外部采样结果转成插件 ViewModel 状态。
@MainActor
final class DeviceMetricsObserver {
    private var cancellables = Set<AnyCancellable>()
    private var dynamicDataTimer: Timer?
    private let viewModels: DevicePluginViewModels

    init(viewModels: DevicePluginViewModels) {
        self.viewModels = viewModels

        CPUService.shared.startMonitoring()
        MemoryService.shared.startMonitoring()
        GPUService.shared.startMonitoring()
        BatteryService.shared.startMonitoring()
        StorageService.shared.startMonitoring()
        SystemMonitorService.shared.startMonitoring()

        Publishers.CombineLatest3(
            CPUService.shared.$cpuUsage,
            CPUService.shared.$perCoreUsage,
            CPUService.shared.$loadAverage
        )
        .combineLatest(Publishers.CombineLatest3(
            CPUService.shared.$userUsage,
            CPUService.shared.$systemUsage,
            CPUService.shared.$idleUsage
        ))
        .sink { [weak self] value, breakdown in
            CPUHistoryService.shared.recordDataPoint(usage: value.0)
            self?.viewModels.cpu.apply(
                usage: value.0,
                perCoreUsage: value.1,
                loadAverage: value.2,
                user: breakdown.0,
                system: breakdown.1,
                idle: breakdown.2
            )
            self?.viewModels.menuBar.applyCPU(usage: value.0, perCoreUsage: value.1)
        }
        .store(in: &cancellables)

        ProcessService.shared.startMonitoring()
        ProcessService.shared.$topProcesses
            .sink { [weak self] processes in
                self?.viewModels.cpu.apply(topProcesses: processes)
            }
            .store(in: &cancellables)

        MemoryService.shared.$memoryUsagePercentage
            .combineLatest(MemoryService.shared.$usedMemory, MemoryService.shared.$totalMemory)
            .sink { [weak self] percentage, used, total in
                MemoryHistoryService.shared.recordDataPoint(pct: percentage, bytes: used)
                self?.viewModels.memory.apply(percentage: percentage, used: used, total: total)
                self?.viewModels.memorySettings.applyMemory(percentage: percentage, used: used, total: total)
                self?.viewModels.menuBar.applyMemory(percentage: percentage, used: used, total: total)
            }
            .store(in: &cancellables)
        LumiMemoryService.shared.startMonitoring()
        Publishers.CombineLatest(
            LumiMemoryService.shared.$currentMemoryFormatted,
            LumiMemoryService.shared.$history
        )
            .sink { [weak self] formatted, history in
                self?.viewModels.memorySettings.applyLumiMemory(currentFormatted: formatted, history: history)
            }
            .store(in: &cancellables)

        GPUService.shared.$utilization
            .sink { utilization in GPUHistoryService.shared.recordDataPoint(usage: utilization) }
            .store(in: &cancellables)
        BatteryService.shared.$watts
            .sink { watts in BatteryHistoryService.shared.recordDataPoint(watts: watts) }
            .store(in: &cancellables)

        GPUService.shared.objectWillChange
            .sink { [weak self] in self?.viewModels.gpu.apply(GPUService.shared) }
            .store(in: &cancellables)
        BatteryService.shared.objectWillChange
            .sink { [weak self] in self?.viewModels.battery.apply(BatteryService.shared) }
            .store(in: &cancellables)
        StorageService.shared.objectWillChange
            .sink { [weak self] in self?.viewModels.storage.apply(StorageService.shared) }
            .store(in: &cancellables)
        SystemMonitorService.shared.$currentMetrics
            .sink { [weak self] metrics in self?.viewModels.systemMonitor.apply(metrics) }
            .store(in: &cancellables)

        CPUHistoryService.shared.$recentHistory
            .combineLatest(CPUHistoryService.shared.$longTermHistory)
            .sink { [weak self] recent, longTerm in
                self?.viewModels.cpuHistory.apply(recent: recent, longTerm: longTerm)
            }
            .store(in: &cancellables)
        GPUHistoryService.shared.$recentHistory
            .combineLatest(GPUHistoryService.shared.$longTermHistory)
            .sink { [weak self] recent, longTerm in
                self?.viewModels.gpuHistory.apply(recent: recent, longTerm: longTerm)
            }
            .store(in: &cancellables)
        MemoryHistoryService.shared.$recentHistory
            .combineLatest(MemoryHistoryService.shared.$longTermHistory)
            .sink { [weak self] recent, longTerm in
                self?.viewModels.memoryHistory.apply(recent: recent, longTerm: longTerm)
                self?.viewModels.memorySettings.applySystemHistory(recent: recent, longTerm: longTerm)
            }
            .store(in: &cancellables)

        dynamicDataTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.viewModels.deviceData.updateDynamicData()
            }
        }
        viewModels.deviceData.updateDynamicData()
        viewModels.gpu.apply(GPUService.shared)
        viewModels.battery.apply(BatteryService.shared)
        viewModels.storage.apply(StorageService.shared)
        viewModels.systemMonitor.apply(SystemMonitorService.shared.currentMetrics)
    }

    func cancel() {
        dynamicDataTimer?.invalidate()
        dynamicDataTimer = nil
        cancellables.removeAll()
        CPUService.shared.stopMonitoring()
        MemoryService.shared.stopMonitoring()
        GPUService.shared.stopMonitoring()
        BatteryService.shared.stopMonitoring()
        StorageService.shared.stopMonitoring()
        SystemMonitorService.shared.stopMonitoring()
        ProcessService.shared.stopMonitoring()
        CPUHistoryService.shared.stopRecording()
        GPUHistoryService.shared.stopRecording()
        MemoryHistoryService.shared.stopRecording()
        BatteryHistoryService.shared.stopRecording()
        LumiMemoryService.shared.stopMonitoring()
    }
}
