import AppKit
import Combine
import Darwin
import Foundation
import os
import LumiLoggingKit
/// Process monitoring service that reports CPU usage per process via libproc.
///
/// 同名多进程（如浏览器/IDE 的多个 Helper）会合并为一条记录并标注份数，
/// 与网络区块的展示口径保持一致。发布的是全部活跃进程，由调用方决定截取前几条。
@MainActor
public final class ProcessService: ObservableObject, SuperLog {
    public static let shared = ProcessService()
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "devicemonitor.process")
    nonisolated(unsafe) static var verbose: Bool = false
    public nonisolated static let emoji = "⚙️"

    // MARK: - Constants

    /// 进程采样间隔。与网络区块的 nettop 采样统一为 1 秒，避免两块榜单
    /// 的刷新节奏不一致。
    nonisolated static let samplingInterval: TimeInterval = 1.0

    /// `proc_taskinfo.pti_total_user/system` 返回的是 mach absolute time ticks。
    ///
    /// 每秒 tick 数由 `mach_timebase_info` 决定：Apple Silicon 为 24 MHz，
    /// Intel 为 1 GHz。不能按固定 100ns 换算，否则 Apple Silicon 上数值
    /// 放大约 2.4 倍、Intel 上放大约 100 倍。
    nonisolated(unsafe) static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    // MARK: - Published Properties

    @Published public var topProcesses: [ProcessMetric] = []

    // MARK: - Private Properties

    private var monitoringTimer: Timer?
    private var samplingTask: Task<Void, Never>?
    private var subscribersCount = 0

    /// Sampling snapshot: [pid: (userTime, systemTime)] in nanoseconds
    private var previousSnapshot: [Int32: (user: UInt64, system: UInt64)] = [:]
    private var previousTimestamp: TimeInterval = 0

    package init() {}

    // MARK: - Public Methods

    public func startMonitoring() {
        subscribersCount += 1
        if monitoringTimer == nil {
            if Self.verbose {
                Self.logger.info("\(self.t)开始进程监控")
            }
            previousTimestamp = Date().timeIntervalSince1970
            sampleProcesses()

            monitoringTimer = Timer.scheduledTimer(withTimeInterval: Self.samplingInterval, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.sampleProcesses()
                }
            }
        }
    }

    public func stopMonitoring() {
        subscribersCount = max(0, subscribersCount - 1)
        if subscribersCount == 0 {
            if Self.verbose {
                Self.logger.info("\(self.t)停止进程监控")
            }
            monitoringTimer?.invalidate()
            monitoringTimer = nil
            samplingTask?.cancel()
            samplingTask = nil
            previousSnapshot.removeAll()
            topProcesses = []
        }
    }

    // MARK: - Internal Methods

    func sampleProcessesInternal() -> [ProcessMetric] {
        let appBundlePaths = Self.runningApplicationBundlePaths()
        let result = Self.sampleProcesses(
            previousSnapshot: previousSnapshot,
            previousTimestamp: previousTimestamp,
            appBundlePaths: appBundlePaths
        )
        previousSnapshot = result.snapshot
        previousTimestamp = result.timestamp
        return result.metrics
    }

    // MARK: - Private Methods

    private func sampleProcesses() {
        guard samplingTask == nil else { return }

        let previousSnapshot = previousSnapshot
        let previousTimestamp = previousTimestamp
        let appBundlePaths = Self.runningApplicationBundlePaths()

        samplingTask = Task.detached(priority: .utility) { [previousSnapshot, previousTimestamp, appBundlePaths] in
            let result = Self.sampleProcesses(
                previousSnapshot: previousSnapshot,
                previousTimestamp: previousTimestamp,
                appBundlePaths: appBundlePaths
            )

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.samplingTask = nil
                guard self.subscribersCount > 0 else { return }
                self.previousSnapshot = result.snapshot
                self.previousTimestamp = result.timestamp
                self.topProcesses = result.metrics
            }
        }
    }

    private static func runningApplicationBundlePaths() -> [Int32: String] {
        Dictionary(
            uniqueKeysWithValues: NSWorkspace.shared.runningApplications.compactMap { app in
                guard let path = app.bundleURL?.path else { return nil }
                return (app.processIdentifier, path)
            }
        )
    }

    private nonisolated static func sampleProcesses(
        previousSnapshot: [Int32: (user: UInt64, system: UInt64)],
        previousTimestamp: TimeInterval,
        appBundlePaths: [Int32: String]
    ) -> (
        metrics: [ProcessMetric],
        snapshot: [Int32: (user: UInt64, system: UInt64)],
        timestamp: TimeInterval
    ) {
        let now = Date().timeIntervalSince1970
        let deltaTime = now - previousTimestamp
        guard deltaTime > 0 else { return ([], previousSnapshot, now) }

        var bufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bufferSize > 0 else { return ([], previousSnapshot, now) }

        let maxCount = Int(bufferSize) / MemoryLayout<pid_t>.size
        var pids = [pid_t](repeating: 0, count: maxCount)

        bufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(bufferSize))
        let actualCount = Int(bufferSize) / MemoryLayout<pid_t>.size
        guard actualCount > 0 else { return ([], previousSnapshot, now) }

        var currentSnapshot: [Int32: (user: UInt64, system: UInt64)] = [:]
        var samples: [CPUSample] = []

        for i in 0 ..< actualCount {
            if Task.isCancelled { break }
            let pid = pids[i]
            guard pid > 0 else { continue }

            var taskInfo = proc_taskinfo()
            let infoSize = MemoryLayout<proc_taskinfo>.size

            let ret = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(infoSize))
            guard ret == Int32(infoSize) else { continue }

            let currentUser = UInt64(taskInfo.pti_total_user)
            let currentSystem = UInt64(taskInfo.pti_total_system)

            currentSnapshot[pid] = (user: currentUser, system: currentSystem)

            if let previous = previousSnapshot[pid] {
                let deltaUser = currentUser &- previous.user
                let deltaSystem = currentSystem &- previous.system
                let totalDelta = deltaUser &+ deltaSystem

                let cpuPercent = cpuPercent(forProcessTimeDelta: totalDelta, elapsedSeconds: deltaTime)

                if cpuPercent > 0.1 {
                    samples.append(CPUSample(
                        pid: pid,
                        name: getProcessName(pid: pid),
                        icon: appBundlePaths[pid],
                        cpuUsage: cpuPercent,
                        memoryUsage: Int64(taskInfo.pti_resident_size)
                    ))
                }
            }
        }

        return (aggregate(samples), currentSnapshot, now)
    }

    /// 单个进程的原始采样值，供聚合与测试使用。
    struct CPUSample: Sendable {
        let pid: Int32
        let name: String
        let icon: String?
        let cpuUsage: Double
        let memoryUsage: Int64
    }

    /// 按进程名聚合同名多进程，并标注份数与本应用。
    ///
    /// 聚合后 CPU 与内存相加；`id` 取组内最小 PID 作为稳定标识，
    /// `isCurrentApp` 只要组内包含 Lumi 自身进程即为真。
    nonisolated static func aggregate(
        _ samples: [CPUSample],
        selfPID: Int32 = Int32(getpid())
    ) -> [ProcessMetric] {
        var groups: [String: CPUAggregate] = [:]

        for sample in samples {
            guard !sample.name.isEmpty else { continue }

            if var group = groups[sample.name] {
                group.pid = min(group.pid, sample.pid)
                group.cpuUsage += sample.cpuUsage
                group.memoryUsage += sample.memoryUsage
                group.instanceCount += 1
                group.isCurrentApp = group.isCurrentApp || sample.pid == selfPID
                if group.icon == nil { group.icon = sample.icon }
                groups[sample.name] = group
            } else {
                groups[sample.name] = CPUAggregate(
                    pid: sample.pid,
                    name: sample.name,
                    icon: sample.icon,
                    cpuUsage: sample.cpuUsage,
                    memoryUsage: sample.memoryUsage,
                    instanceCount: 1,
                    isCurrentApp: sample.pid == selfPID
                )
            }
        }

        return groups.values
            .map { group in
                ProcessMetric(
                    id: group.pid,
                    name: group.name,
                    icon: group.icon,
                    cpuUsage: group.cpuUsage,
                    memoryUsage: group.memoryUsage,
                    instanceCount: group.instanceCount,
                    isCurrentApp: group.isCurrentApp
                )
            }
            .sorted { $0.cpuUsage > $1.cpuUsage }
    }

    private struct CPUAggregate {
        var pid: Int32
        var name: String
        var icon: String?
        var cpuUsage: Double
        var memoryUsage: Int64
        var instanceCount: Int
        var isCurrentApp: Bool
    }

    /// 取可执行文件完整路径的文件名，避免 `proc_name` 的 16 字符截断
    /// 造成不同进程被误判为同名（与网络区块的名称口径对齐）。
    private nonisolated static func getProcessName(pid: Int32) -> String {
        var pathBuffer = [CChar](repeating: 0, count: 4096)
        if proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count)) > 0 {
            let name = (String(cString: pathBuffer) as NSString).lastPathComponent
            if !name.isEmpty { return name }
        }

        let bufferSize = 1024
        var nameBuffer = [CChar](repeating: 0, count: bufferSize)
        let result = proc_name(pid, &nameBuffer, UInt32(bufferSize))

        if result > 0 {
            let nameStr = String(cString: nameBuffer)
            if !nameStr.isEmpty {
                return nameStr
            }
        }
        return "PID \(pid)"
    }

    nonisolated static func cpuPercent(
        forProcessTimeDelta totalDelta: UInt64,
        elapsedSeconds deltaTime: TimeInterval,
        timebase: mach_timebase_info_data_t = ProcessService.timebase
    ) -> Double {
        guard deltaTime > 0 else { return 0 }
        // mach ticks → 纳秒 → CPU 秒数；100% 表示占满一个核心。
        let nanoseconds = Double(totalDelta) * Double(timebase.numer) / Double(timebase.denom)
        return nanoseconds / (deltaTime * 1_000_000_000.0) * 100.0
    }
}
