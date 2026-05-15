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
    public nonisolated static let verbose: Bool = false

    // MARK: - Published Properties

    /// Current total CPU usage percentage (0.0 - 100.0)
    @Published public var cpuUsage: Double = 0.0

    /// Per-core instantaneous usage percentages (0.0 - 100.0)
    @Published public var perCoreUsage: [Double] = []

    /// System load averages (1m, 5m, 15m)
    @Published public var loadAverage: [Double] = [0, 0, 0]

    // MARK: - Private Properties

    private var monitoringTimer: Timer?
    private var samplingTask: Task<Void, Never>?
    private var subscribersCount = 0

    // CPU Calculation State
    private var previousTicks: [integer_t]?

    package init() {}

    // MARK: - Public Methods

    public func startMonitoring() {
        subscribersCount += 1
        if monitoringTimer == nil {
            if Self.verbose { Self.logger.info("\(self.t)开始 CPU 监控") }
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
            if Self.verbose { Self.logger.info("\(self.t)停止 CPU 监控") }
            monitoringTimer?.invalidate()
            monitoringTimer = nil
            samplingTask?.cancel()
            samplingTask = nil
            previousTicks = nil
        }
    }

    // MARK: - Private Methods

    private func updateCPUUsage() {
        guard samplingTask == nil else { return }
        let previousTicks = previousTicks

        samplingTask = Task.detached(priority: .utility) { [previousTicks] in
            let snapshot = Self.calculateCPUSnapshot(previousTicks: previousTicks)
            let load = Self.getLoadAverage()

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.samplingTask = nil
                guard self.subscribersCount > 0 else { return }

                self.previousTicks = snapshot.currentTicks
                self.cpuUsage = snapshot.totalUsage
                self.perCoreUsage = snapshot.perCoreUsage
                self.loadAverage = load
            }
        }
    }

    private nonisolated static func calculateCPUSnapshot(
        previousTicks: [integer_t]?
    ) -> (totalUsage: Double, perCoreUsage: [Double], currentTicks: [integer_t]) {
        var processorInfo = processor_info_array_t(nil)
        var processorMsgCount = mach_msg_type_number_t(0)
        var processorCount = natural_t(0)

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &processorCount, &processorInfo, &processorMsgCount)

        guard result == KERN_SUCCESS, let processorInfo else {
            return (0.0, [], previousTicks ?? [])
        }
        defer {
            let size = Int(processorMsgCount) * MemoryLayout<integer_t>.stride
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: processorInfo), vm_size_t(size))
        }

        let currentTicks = Array(UnsafeBufferPointer(start: processorInfo, count: Int(processorMsgCount)))

        var totalUsage = 0.0
        var coreUsage: [Double] = []

        if let previousTicks, previousTicks.count >= currentTicks.count {
            for i in 0..<Int(processorCount) {
                let base = i * Int(CPU_STATE_MAX)

                let user = currentTicks[base + Int(CPU_STATE_USER)] - previousTicks[base + Int(CPU_STATE_USER)]
                let system = currentTicks[base + Int(CPU_STATE_SYSTEM)] - previousTicks[base + Int(CPU_STATE_SYSTEM)]
                let nice = currentTicks[base + Int(CPU_STATE_NICE)] - previousTicks[base + Int(CPU_STATE_NICE)]
                let idle = currentTicks[base + Int(CPU_STATE_IDLE)] - previousTicks[base + Int(CPU_STATE_IDLE)]

                let inUse = user + system + nice
                let total = user + system + nice + idle
                let usage = total > 0 ? Double(inUse) / Double(total) * 100.0 : 0.0

                coreUsage.append(usage)
                totalUsage += usage
            }

            if processorCount > 0 {
                totalUsage /= Double(processorCount)
            }
        }

        return (totalUsage, coreUsage, currentTicks)
    }

    private nonisolated static func getLoadAverage() -> [Double] {
        var loadAvg = [Double](repeating: 0.0, count: 3)
        var samples = [Double](repeating: 0.0, count: 3)

        if getloadavg(&samples, 3) == 3 {
            loadAvg = samples
        }

        return loadAvg
    }
}
