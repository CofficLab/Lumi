import Combine
import Foundation
import SwiftUI

@MainActor
final class StorageManagerViewModel: ObservableObject {
    @Published private(set) var externalVolumes: [VolumeInfo] = []

    func apply(_ service: StorageService) {
        externalVolumes = service.externalVolumes
    }
}

@MainActor
final class DeviceHistoryViewModel<Point>: ObservableObject {
    @Published private(set) var recentHistory: [Point] = []
    @Published private(set) var longTermHistory: [Point] = []

    func apply(recent: [Point], longTerm: [Point]) {
        recentHistory = recent
        longTermHistory = longTerm
    }
}

@MainActor
final class DevicePluginViewModels: ObservableObject {
    let deviceData: DeviceData
    let cpu: CPUManagerViewModel
    let memory: MemoryManagerViewModel
    let memorySettings: MemorySettingsViewModel
    let gpu: GPUManagerViewModel
    let battery: BatteryManagerViewModel
    let storage: StorageManagerViewModel
    let systemMonitor: SystemMonitorViewModel
    let menuBar: DeviceInfoMenuBarContentViewModel
    let cpuHistory = DeviceHistoryViewModel<CPUDataPoint>()
    let gpuHistory = DeviceHistoryViewModel<GPUDataPoint>()
    let memoryHistory = DeviceHistoryViewModel<MemoryDataPoint>()
    private var cancellables = Set<AnyCancellable>()

    init() {
        deviceData = DeviceData()
        cpu = CPUManagerViewModel()
        memory = MemoryManagerViewModel()
        memorySettings = MemorySettingsViewModel()
        gpu = GPUManagerViewModel()
        battery = BatteryManagerViewModel()
        storage = StorageManagerViewModel()
        systemMonitor = SystemMonitorViewModel()
        menuBar = DeviceInfoMenuBarContentViewModel()

        let publishers: [AnyPublisher<Void, Never>] = [
            cpu.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            memory.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            memorySettings.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            gpu.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            battery.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            storage.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            systemMonitor.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            menuBar.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            cpuHistory.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            gpuHistory.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            memoryHistory.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            deviceData.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
        ]
        Publishers.MergeMany(publishers)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
