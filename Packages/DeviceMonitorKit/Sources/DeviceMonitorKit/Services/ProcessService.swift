import Foundation
import Combine
import MagicKit
import os
import AppKit

/// Process monitoring service that reports top N CPU-consuming processes via libproc.
@MainActor
public final class ProcessService: ObservableObject, SuperLog {
    public static let shared = ProcessService()
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "devicemonitor.process")
    nonisolated public static let emoji = "⚙️"

    // MARK: - Constants

    private static let processLimit = 5

    // MARK: - Published Properties

    @Published public var topProcesses: [ProcessMetric] = []

    // MARK: - Private Properties

    private var monitoringTimer: Timer?
    private var subscribersCount = 0

    /// Sampling snapshot: [pid: (userTime, systemTime)] in nanoseconds
    private var previousSnapshot: [Int32: (user: UInt64, system: UInt64)] = [:]
    private var previousTimestamp: TimeInterval = 0

    package init() {}

    // MARK: - Public Methods

    public func startMonitoring() {
        subscribersCount += 1
        if monitoringTimer == nil {
            Self.logger.info("\(self.t)开始进程监控")
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
            Self.logger.info("\(self.t)停止进程监控")
            monitoringTimer?.invalidate()
            monitoringTimer = nil
            previousSnapshot.removeAll()
            topProcesses = []
        }
    }

    // MARK: - Internal Methods

    func sampleProcessesInternal() -> [ProcessMetric] {
        let now = Date().timeIntervalSince1970
        let deltaTime = now - previousTimestamp
        guard deltaTime > 0 else { return [] }

        var bufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bufferSize > 0 else { return [] }

        let maxCount = Int(bufferSize) / MemoryLayout<pid_t>.size
        var pids = [pid_t](repeating: 0, count: maxCount)

        bufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(bufferSize))
        let actualCount = Int(bufferSize) / MemoryLayout<pid_t>.size
        guard actualCount > 0 else { return [] }

        var currentSnapshot: [Int32: (user: UInt64, system: UInt64)] = [:]
        var results: [ProcessMetric] = []

        for i in 0..<actualCount {
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

                let cpuPercent = Double(totalDelta) / (deltaTime * 1_000_000_000) * 100.0

                if cpuPercent > 0.1 {
                    let name = getProcessName(pid: pid)
                    let icon = getProcessBundlePath(pid: pid)

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

        previousSnapshot = currentSnapshot
        previousTimestamp = now

        return results.sorted { $0.cpuUsage > $1.cpuUsage }.prefix(Self.processLimit).map { $0 }
    }

    // MARK: - Private Methods

    private func sampleProcesses() {
        let results = sampleProcessesInternal()
        topProcesses = results
    }

    private func getProcessName(pid: Int32) -> String {
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

    private func getProcessBundlePath(pid: Int32) -> String? {
        NSWorkspace.shared.runningApplications
            .first { $0.processIdentifier == pid }?
            .bundleURL?
            .path
    }
}
