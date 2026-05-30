import AppKit
import Darwin
import DeviceMonitorKit
import Foundation
import IOKit.ps
import SwiftUI

// Helper class to hold timer avoiding actor isolation issues
private final class TimerHolder: @unchecked Sendable {
    var timer: Timer?
    
    func invalidate() {
        timer?.invalidate()
        timer = nil
    }
}

/// 设备信息数据模型
@MainActor
class DeviceData: ObservableObject {
    // MARK: - Published Properties

    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0
    @Published var memoryTotal: UInt64 = 0
    @Published var memoryUsed: UInt64 = 0
    @Published var diskTotal: Int64 = 0
    @Published var diskUsed: Int64 = 0
    @Published var batteryLevel: Double = 0.0
    @Published var isCharging: Bool = false
    @Published var uptime: TimeInterval = 0

    // MARK: - Static Properties

    let deviceName: String
    let osVersion: String
    let processorName: String
    let coreCount: Int

    // MARK: - Private Properties

    private nonisolated let timerHolder = TimerHolder()
    private var isMonitoring = false
    private let cpuUsageProvider: @MainActor () -> Double
    private let cpuMonitoringStarter: @MainActor () -> Void
    private let cpuMonitoringStopper: @MainActor () -> Void

    // MARK: - Initialization

    init(
        cpuUsageProvider: @escaping @MainActor () -> Double = {
            CPUService.shared.cpuUsage
        },
        cpuMonitoringStarter: @escaping @MainActor () -> Void = {
            CPUService.shared.startMonitoring()
        },
        cpuMonitoringStopper: @escaping @MainActor () -> Void = {
            CPUService.shared.stopMonitoring()
        }
    ) {
        self.cpuUsageProvider = cpuUsageProvider
        self.cpuMonitoringStarter = cpuMonitoringStarter
        self.cpuMonitoringStopper = cpuMonitoringStopper
        self.deviceName = Host.current().localizedName ?? "Unknown Mac"

        let os = ProcessInfo.processInfo.operatingSystemVersion
        self.osVersion = "macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"

        self.processorName = DeviceData.getProcessorName()
        self.coreCount = ProcessInfo.processInfo.activeProcessorCount

        self.memoryTotal = ProcessInfo.processInfo.physicalMemory

        self.updateDynamicData()
        self.startMonitoring()
    }

    deinit {
        timerHolder.invalidate()
        if isMonitoring {
            Task { @MainActor [cpuMonitoringStopper] in
                cpuMonitoringStopper()
            }
        }
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard timerHolder.timer == nil else { return }
        isMonitoring = true
        cpuMonitoringStarter()

        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateDynamicData()
            }
        }
        timerHolder.timer = timer
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        timerHolder.invalidate()
        cpuMonitoringStopper()
    }

    // MARK: - Data Fetching

    private func updateDynamicData() {
        self.cpuUsage = getCPUUsage()
        self.updateMemoryUsage()
        self.updateDiskUsage()
        self.updateBatteryStatus()
        self.uptime = ProcessInfo.processInfo.systemUptime
    }

    // MARK: - Helpers

    private static func getProcessorName() -> String {
        var size: Int = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &model, &size, nil, 0)
        return String(cString: model)
    }

    private func getCPUUsage() -> Double {
        cpuUsageProvider()
    }

    private func updateMemoryUsage() {
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let active = UInt64(stats.active_count) * UInt64(pageSize)
            let wired = UInt64(stats.wire_count) * UInt64(pageSize)
            let compressed = UInt64(stats.compressor_page_count) * UInt64(pageSize)
            // Approximate "Used" memory as App Memory (Active) + Wired + Compressed
            self.memoryUsed = active + wired + compressed
            self.memoryUsage = Double(self.memoryUsed) / Double(self.memoryTotal)
        }
    }

    private func updateDiskUsage() {
        let fileURL = URL(fileURLWithPath: "/")
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            if let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity {
                self.diskTotal = Int64(total)
                self.diskUsed = Int64(total - available)
            }
        } catch {
            DeviceInfoPlugin.logger.error("Error retrieving disk usage: \(error)")
        }
    }

    private func updateBatteryStatus() {
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]

        if let sources = sources, let source = sources.first {
            let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]

            if let current = description?[kIOPSCurrentCapacityKey] as? Int,
               let max = description?[kIOPSMaxCapacityKey] as? Int {
                self.batteryLevel = Double(current) / Double(max)
            }

            if let isCharging = description?[kIOPSIsChargingKey] as? Bool {
                self.isCharging = isCharging
            }
        }
    }
}
