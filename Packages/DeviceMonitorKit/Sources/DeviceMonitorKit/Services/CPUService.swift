import Foundation
import MagicKit
import Combine
import os

/// CPU monitoring service providing real-time CPU usage data.
@MainActor
public final class CPUService: ObservableObject, SuperLog {
    public static let shared = CPUService()
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "devicemonitor.cpu")
    public nonisolated static let emoji = "🔍"

    // MARK: - Published Properties

    /// Current total CPU usage percentage (0.0 - 100.0)
    @Published public var cpuUsage: Double = 0.0

    /// Per-core instantaneous usage percentages (0.0 - 100.0)
    @Published public var perCoreUsage: [Double] = []

    /// System load averages (1m, 5m, 15m)
    @Published public var loadAverage: [Double] = [0, 0, 0]

    // MARK: - Private Properties

    private var monitoringTimer: Timer?
    private var subscribersCount = 0

    // CPU Calculation State
    private var previousInfo = processor_info_array_t(nil)
    private var previousCount = mach_msg_type_number_t(0)

    package init() {}

    // MARK: - Public Methods

    public func startMonitoring() {
        subscribersCount += 1
        if monitoringTimer == nil {
            Self.logger.info("\(self.t)开始 CPU 监控")
            updateCPUUsage()

            monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateCPUUsage()
                }
            }
        }
    }

    public func stopMonitoring() {
        subscribersCount = max(0, subscribersCount - 1)
        if subscribersCount == 0 {
            Self.logger.info("\(self.t)停止 CPU 监控")
            monitoringTimer?.invalidate()
            monitoringTimer = nil

            if let prevInfo = previousInfo {
                let prevSize = Int(previousCount) * MemoryLayout<integer_t>.stride
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevInfo), vm_size_t(prevSize))
                previousInfo = nil
                previousCount = 0
            }
        }
    }

    // MARK: - Private Methods

    private func updateCPUUsage() {
        let snapshot = calculateCPUSnapshot()
        let load = getLoadAverage()

        cpuUsage = snapshot.totalUsage
        perCoreUsage = snapshot.perCoreUsage
        loadAverage = load
    }

    private func calculateCPUSnapshot() -> (totalUsage: Double, perCoreUsage: [Double]) {
        var processorInfo = processor_info_array_t(nil)
        var processorMsgCount = mach_msg_type_number_t(0)
        var processorCount = natural_t(0)

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &processorCount, &processorInfo, &processorMsgCount)

        guard result == KERN_SUCCESS else {
            return (0.0, [])
        }

        var totalUsage = 0.0
        var coreUsage: [Double] = []

        if let prevInfo = previousInfo {
            for i in 0..<Int(processorCount) {
                let base = i * Int(CPU_STATE_MAX)

                let user = processorInfo![base + Int(CPU_STATE_USER)] - prevInfo[base + Int(CPU_STATE_USER)]
                let system = processorInfo![base + Int(CPU_STATE_SYSTEM)] - prevInfo[base + Int(CPU_STATE_SYSTEM)]
                let nice = processorInfo![base + Int(CPU_STATE_NICE)] - prevInfo[base + Int(CPU_STATE_NICE)]
                let idle = processorInfo![base + Int(CPU_STATE_IDLE)] - prevInfo[base + Int(CPU_STATE_IDLE)]

                let inUse = user + system + nice
                let total = user + system + nice + idle
                let usage = total > 0 ? Double(inUse) / Double(total) * 100.0 : 0.0

                coreUsage.append(usage)
                totalUsage += usage
            }

            let prevSize = Int(previousCount) * MemoryLayout<integer_t>.stride
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevInfo), vm_size_t(prevSize))

            if processorCount > 0 {
                totalUsage /= Double(processorCount)
            }
        }

        previousInfo = processorInfo
        previousCount = processorMsgCount

        return (totalUsage, coreUsage)
    }

    private func getLoadAverage() -> [Double] {
        var loadAvg = [Double](repeating: 0.0, count: 3)
        var samples = [Double](repeating: 0.0, count: 3)

        if getloadavg(&samples, 3) == 3 {
            loadAvg = samples
        }

        return loadAvg
    }
}
