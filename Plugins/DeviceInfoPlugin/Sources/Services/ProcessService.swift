import AppKit
import Combine
import Foundation
import os
import SuperLogKit

/// Process monitoring service that reports top N CPU-consuming processes via libproc.
@MainActor
public final class ProcessService: ObservableObject, SuperLog {
    public static let shared = ProcessService()
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "devicemonitor.process")
    nonisolated(unsafe) static var verbose: Bool = true
    public nonisolated static let emoji = "⚙️"

    // MARK: - Constants

    private nonisolated static let processLimit = 5
    /// `proc_taskinfo.pti_total_user/system` reports CPU time in 100ns ticks.
    private nonisolated static let processTimeTicksPerSecond = 10000000.0

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

            monitoringTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
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
        var results: [ProcessMetric] = []

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
                    let name = getProcessName(pid: pid)
                    let icon = appBundlePaths[pid]

                    results.append(ProcessMetric(
                        id: pid,
                        name: name,
                        icon: icon,
                        cpuUsage: cpuPercent,
                        memoryUsage: Int64(taskInfo.pti_resident_size)
                    ))
                }
            }
        }

        return (
            results.sorted { $0.cpuUsage > $1.cpuUsage }.prefix(Self.processLimit).map { $0 },
            currentSnapshot,
            now
        )
    }

    private nonisolated static func getProcessName(pid: Int32) -> String {
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
        elapsedSeconds deltaTime: TimeInterval
    ) -> Double {
        guard deltaTime > 0 else { return 0 }
        return Double(totalDelta) / (deltaTime * processTimeTicksPerSecond) * 100.0
    }
}
