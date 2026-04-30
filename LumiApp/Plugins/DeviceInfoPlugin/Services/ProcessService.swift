import Foundation
import Combine
import os
import Darwin
import MagicKit

/// 进程监控服务：通过 libproc 采集 Top N CPU 占用进程
///
/// 采用 delta 快照方式计算每个进程的 CPU 占用百分比，
/// 每 3 秒采样一次，按 CPU% 降序返回前 N 个进程。
@MainActor
class ProcessService: ObservableObject, SuperLog {
    static let shared = ProcessService()
    nonisolated static let emoji = "⚙️"
    nonisolated static let verbose: Bool = false

    // MARK: - 常量/静态属性

    private static let logger = DeviceInfoPlugin.logger
    private static let processLimit = 5

    // MARK: - Published Properties

    @Published var topProcesses: [ProcessMetric] = []

    // MARK: - 私有属性

    private var monitoringTimer: Timer?
    private var subscribersCount = 0

    /// 采样快照: [pid: (userTime, systemTime)]，单位 nanoseconds
    private var previousSnapshot: [Int32: (user: UInt64, system: UInt64)] = [:]
    private var previousTimestamp: TimeInterval = 0

    private init() {}

    // MARK: - 公开方法

    func startMonitoring() {
        subscribersCount += 1
        if monitoringTimer == nil {
            if Self.verbose {
                Self.logger.info("\(self.t)Starting process monitoring")
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

    func stopMonitoring() {
        subscribersCount = max(0, subscribersCount - 1)
        if subscribersCount == 0 {
            if Self.verbose {
                Self.logger.info("\(self.t)Stopping process monitoring")
            }
            monitoringTimer?.invalidate()
            monitoringTimer = nil
            previousSnapshot.removeAll()
            topProcesses = []
        }
    }

    // MARK: - 私有方法

    private func sampleProcesses() {
        let now = Date().timeIntervalSince1970
        let deltaTime = now - previousTimestamp
        guard deltaTime > 0 else { return }

        let numCPUs = Double(ProcessInfo.processInfo.activeProcessorCount)

        // 获取所有 PID
        var bufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bufferSize > 0 else { return }

        let maxCount = Int(bufferSize) / MemoryLayout<pid_t>.size
        var pids = [pid_t](repeating: 0, count: maxCount)

        bufferSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(bufferSize))
        let actualCount = Int(bufferSize) / MemoryLayout<pid_t>.size
        guard actualCount > 0 else { return }

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

            // 与上次快照对比计算 CPU% delta
            if let previous = previousSnapshot[pid] {
                let deltaUser = currentUser &- previous.user
                let deltaSystem = currentSystem &- previous.system
                let totalDelta = deltaUser &+ deltaSystem

                // pti_total_user/system 单位为 nanoseconds
                let cpuPercent = Double(totalDelta) / (deltaTime * numCPUs * 1_000_000_000) * 100.0

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

        // 排序取 top N
        let topN = results.sorted { $0.cpuUsage > $1.cpuUsage }.prefix(Self.processLimit)
        topProcesses = Array(topN)
    }

    private func getProcessName(pid: Int32) -> String {
        let bufferSize = 1024
        var nameBuffer = [CChar](repeating: 0, count: bufferSize)
        let result = proc_name(pid, &nameBuffer, UInt32(bufferSize))

        if result > 0, let name = String(validatingUTF8: nameBuffer), !name.isEmpty {
            return name
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
