import AppKit
import Darwin
import Foundation
import IOKit.ps
import os
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
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.device-data")

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
    private var samplingTask: Task<Void, Never>?
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
        self.coreCount = Self.physicalCoreCount()

        self.memoryTotal = ProcessInfo.processInfo.physicalMemory

        self.updateDynamicData()
        self.startMonitoring()
    }

    deinit {
        timerHolder.invalidate()
        samplingTask?.cancel()
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
        samplingTask?.cancel()
        samplingTask = nil
        cpuMonitoringStopper()
    }

    // MARK: - Data Fetching

    private func updateDynamicData() {
        guard samplingTask == nil else { return }

        // CPU 使用率已在主线程由 CPUService 维护，直接读取
        let cpuUsage = self.cpuUsageProvider()

        samplingTask = Task.detached(priority: .utility) { [weak self] in
            // 采集其他数据在后台线程
            let memoryData = self?.getMemoryData() ?? (used: 0, total: 0)
            let diskData = self?.getDiskData() ?? (total: 0, used: 0)
            let batteryData = self?.getBatteryData() ?? (level: 0.0, isCharging: false)
            let uptime = ProcessInfo.processInfo.systemUptime

            // 回到主线程更新 @Published 属性
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.samplingTask = nil
                self.cpuUsage = cpuUsage
                self.memoryUsed = memoryData.used
                self.memoryTotal = memoryData.total
                self.memoryUsage = Double(memoryData.used) / Double(memoryData.total)
                self.diskTotal = diskData.total
                self.diskUsed = diskData.used
                self.batteryLevel = batteryData.level
                self.isCharging = batteryData.isCharging
                self.uptime = uptime
            }
        }
    }

    // MARK: - Helpers

    /// 物理 CPU 核心数（`hw.physicalcpu`），与系统监视器一致；失败时回退到逻辑核数。
    nonisolated static func physicalCoreCount() -> Int {
        var physicalCores: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("hw.physicalcpu", &physicalCores, &size, nil, 0) == 0, physicalCores > 0 {
            return Int(physicalCores)
        }
        return ProcessInfo.processInfo.activeProcessorCount
    }

    private static func getProcessorName() -> String {
        var size: Int = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0 else {
            return ""
        }
        var model = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &model, &size, nil, 0) == 0 else {
            return ""
        }
        let bytes = model.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    private func getCPUUsage() -> Double {
        cpuUsageProvider()
    }

    private nonisolated func getMemoryData() -> (used: UInt64, total: UInt64) {
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO, $0, &count)
            }
        }

        let total = ProcessInfo.processInfo.physicalMemory

        if result == KERN_SUCCESS {
            let active = UInt64(stats.active_count) * UInt64(pageSize)
            let wired = UInt64(stats.wire_count) * UInt64(pageSize)
            let compressed = UInt64(stats.compressor_page_count) * UInt64(pageSize)
            // Approximate "Used" memory as App Memory (Active) + Wired + Compressed
            let used = active + wired + compressed
            return (used, total)
        }

        return (0, total)
    }

    private nonisolated func getDiskData() -> (total: Int64, used: Int64) {
        let fileURL = URL(fileURLWithPath: "/")
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            if let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity {
                return (Int64(total), Int64(total - available))
            }
        } catch {
            Self.logger.error("Failed to read disk capacity: \(error.localizedDescription)")
        }
        return (0, 0)
    }

    private nonisolated func getBatteryData() -> (level: Double, isCharging: Bool) {
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]

        var level: Double = 0.0
        var isCharging: Bool = false

        if let sources = sources, let source = sources.first {
            let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]

            if let current = description?[kIOPSCurrentCapacityKey] as? Int,
               let max = description?[kIOPSMaxCapacityKey] as? Int {
                level = Double(current) / Double(max)
            }

            if let charging = description?[kIOPSIsChargingKey] as? Bool {
                isCharging = charging
            }
        }

        return (level, isCharging)
    }
}
