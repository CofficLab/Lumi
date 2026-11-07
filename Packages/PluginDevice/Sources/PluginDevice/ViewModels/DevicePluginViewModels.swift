import Combine
import Foundation

@MainActor
final class StorageManagerViewModel: ObservableObject {
    @Published private(set) var externalVolumes: [VolumeInfo] = []

    func apply(_ service: StorageService) {
        externalVolumes = service.externalVolumes
    }
}

@MainActor
final class DeviceHistoryViewModel<Point: DeviceHistorySample>: ObservableObject {
    @Published private(set) var recentHistory: [Point] = []
    @Published private(set) var longTermHistory: [Point] = []

    func apply(recent: [Point], longTerm: [Point]) {
        recentHistory = recent
        longTermHistory = longTerm
    }

    /// 按时间范围裁剪历史数据。
    ///
    /// 1 小时范围取秒级高频缓冲,更长范围取分钟级聚合缓冲;
    /// 两者都按 `range.duration` 剔除过期样本,避免不同范围展示同一份数据。
    func data(for range: some DeviceHistoryRange) -> [Point] {
        let cutoff = Date().timeIntervalSince1970 - range.duration
        let buffer = range.usesHighResolutionBuffer ? recentHistory : longTermHistory
        return buffer.filter { $0.timestamp >= cutoff }
    }
}

@MainActor
final class DevicePluginViewModels: ObservableObject {
    let deviceData: DeviceData
    let cpu: CPUManagerViewModel
    let memory: MemoryManagerViewModel
    let gpu: GPUManagerViewModel
    let battery: BatteryManagerViewModel
    let storage: StorageManagerViewModel
    let systemMonitor: SystemMonitorViewModel
    let thermal: ThermalViewModel
    let menuBar: DeviceInfoMenuBarContentViewModel
    let cpuHistory = DeviceHistoryViewModel<CPUDataPoint>()
    let thermalHistory = DeviceHistoryViewModel<ThermalDataPoint>()
    let gpuHistory = DeviceHistoryViewModel<GPUDataPoint>()
    let memoryHistory = DeviceHistoryViewModel<MemoryDataPoint>()

    init() {
        deviceData = DeviceData()
        cpu = CPUManagerViewModel()
        memory = MemoryManagerViewModel()
        gpu = GPUManagerViewModel()
        battery = BatteryManagerViewModel()
        storage = StorageManagerViewModel()
        systemMonitor = SystemMonitorViewModel()
        thermal = ThermalViewModel()
        menuBar = DeviceInfoMenuBarContentViewModel()
    }
}
