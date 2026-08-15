import Foundation
import SuperLogKit
import Combine
import os

/// CPU monitoring service providing real-time CPU usage data.
@MainActor
public final class CPUService: ObservableObject, SuperLog {
    public static let shared = CPUService()
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "devicemonitor.cpu")
    public nonisolated static let emoji = "🖥️"
    public nonisolated(unsafe) static var verbose: Bool = false

    // MARK: - Published Properties

    /// Current total CPU usage percentage (0.0 - 100.0)
    @Published public var cpuUsage: Double = 0.0

    /// Per-core instantaneous usage percentages (0.0 - 100.0)
    @Published public var perCoreUsage: [Double] = []

    /// System load averages (1m, 5m, 15m)
    @Published public var loadAverage: [Double] = [0, 0, 0]

    /// CPU usage breakdown: user percentage (0-100)
    @Published public var userUsage: Double = 0.0

    /// CPU usage breakdown: system percentage (0-100)
    @Published public var systemUsage: Double = 0.0

    /// CPU usage breakdown: idle percentage (0-100)
    @Published public var idleUsage: Double = 100.0

    // MARK: - Private Properties

    private var monitoringTimer: Timer?
    private var samplingTask: Task<Void, Never>?
    private var subscribersCount = 0

    /// 心跳节流计数：每次 CPU 采样 tick 自增，每 N 次打一条日志（1Hz 定时器 → 约每 10 秒一条）。
    /// 用于排查 CPU 占用持续 100% 时确认本采样链路是否在主线程持续运行。
    private var tickCount = 0
    private let tickLogEvery = 10

    // CPU Calculation State
    private var previousTicks: [integer_t]?

    package init() {}

    // MARK: - Public Methods

    public func startMonitoring() {
        subscribersCount += 1
        if monitoringTimer == nil {
            if Self.verbose { Self.logger.info("\(Self.t)\(Self.emoji) 开始 CPU 监控") }
            updateCPUUsage()

            let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateCPUUsage()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            monitoringTimer = timer
        }
    }

    public func stopMonitoring() {
        subscribersCount = max(0, subscribersCount - 1)
        if subscribersCount == 0 {
            if Self.verbose { Self.logger.info("\(Self.t)\(Self.emoji) 停止 CPU 监控") }
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
                self.userUsage = snapshot.userUsage
                self.systemUsage = snapshot.systemUsage
                self.idleUsage = snapshot.idleUsage

                // 节流心跳：确认 1Hz CPU 采样链路在持续运行。
                self.tickCount += 1
                if Self.verbose, self.tickCount % self.tickLogEvery == 0 {
                    Self.logger.info("\(self.t)\(Self.emoji) tick #\(self.tickCount) 采样完成，cpu=\(String(format: "%.1f", snapshot.totalUsage))%")
                }
            }
        }
    }

    private nonisolated static func calculateCPUSnapshot(
        previousTicks: [integer_t]?
    ) -> (totalUsage: Double, perCoreUsage: [Double], userUsage: Double, systemUsage: Double, idleUsage: Double, currentTicks: [integer_t]) {
        var processorInfo = processor_info_array_t(nil)
        var processorMsgCount = mach_msg_type_number_t(0)
        var processorCount = natural_t(0)

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &processorCount, &processorInfo, &processorMsgCount)

        guard result == KERN_SUCCESS, let processorInfo else {
            return (0.0, [], 0.0, 0.0, 100.0, previousTicks ?? [])
        }
        defer {
            let size = Int(processorMsgCount) * MemoryLayout<integer_t>.stride
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: processorInfo), vm_size_t(size))
        }

        let currentTicks = Array(UnsafeBufferPointer(start: processorInfo, count: Int(processorMsgCount)))

        var totalUsage = 0.0
        var logicalCoreUsage: [Double] = []
        var totalUser: Int64 = 0
        var totalSystem: Int64 = 0
        var totalIdle: Int64 = 0
        var totalNice: Int64 = 0

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

                logicalCoreUsage.append(usage)
                totalUsage += usage

                totalUser += Int64(user)
                totalSystem += Int64(system)
                totalNice += Int64(nice)
                totalIdle += Int64(idle)
            }

            if processorCount > 0 {
                totalUsage /= Double(processorCount)
            }
        }

        // 将逻辑核心使用率聚合为物理核心使用率
        let physicalCoreCount = DeviceData.physicalCoreCount()
        let coreUsage: [Double]
        if physicalCoreCount > 0 && physicalCoreCount < logicalCoreUsage.count {
            // 超线程情况：每 N 个逻辑核心聚合成 1 个物理核心
            let logicalPerPhysical = logicalCoreUsage.count / physicalCoreCount
            var aggregatedUsage: [Double] = []
            for i in 0..<physicalCoreCount {
                let startIdx = i * logicalPerPhysical
                let endIdx = min(startIdx + logicalPerPhysical, logicalCoreUsage.count)
                let sum = logicalCoreUsage[startIdx..<endIdx].reduce(0, +)
                aggregatedUsage.append(sum / Double(endIdx - startIdx))
            }
            coreUsage = aggregatedUsage
        } else {
            // 无超线程或获取失败：直接使用逻辑核心
            coreUsage = logicalCoreUsage
        }

        let allTicks = totalUser + totalSystem + totalNice + totalIdle
        let userPct = allTicks > 0 ? Double(totalUser + totalNice) / Double(allTicks) * 100.0 : 0.0
        let systemPct = allTicks > 0 ? Double(totalSystem) / Double(allTicks) * 100.0 : 0.0
        let idlePct = allTicks > 0 ? Double(totalIdle) / Double(allTicks) * 100.0 : 100.0

        return (totalUsage, coreUsage, userPct, systemPct, idlePct, currentTicks)
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
