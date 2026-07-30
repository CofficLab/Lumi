import Foundation
import SuperLogKit
import AppKit
import Combine

@MainActor
public class ProcessMonitorService: ObservableObject, SuperLog {
    public static let shared = ProcessMonitorService()
    public nonisolated static let emoji = "👮"
    public nonisolated static let verbose: Bool = true
    
    // Sampling interval
    private let interval: TimeInterval = 1.0
    
    // 3-point moving average queue
    private var historyBuffer: [String: [(Double, Double)]] = [:] // Name -> [(In, Out)]
    private let smoothingWindow = 3
    
    // Process info cache
    private var processDetails: [Int: (name: String, icon: NSImage?)] = [:]

    // Background queue for icon fetching
    private let iconQueue = DispatchQueue(label: "com.coffic.lumi.process-icons", qos: .utility)
    
    // Runtime status
    private var isRunning = false
    private var refCount = 0
    private var task: Process?
    private var outputPipe: Pipe?
    private var dataAvailableObserver: NSObjectProtocol?

    /// 心跳节流计数：nettop 子进程(-L 0 永久循环)每次输出回调自增，每 N 次打一条。
    /// nettop 会高频持续产出数据，若本回调狂触发是 100% CPU 的直接信号。
    private var tickCount = 0
    private let tickLogEvery = 20
    
    // Data publishing
    @Published var processes: [NetworkProcess] = []
    
    private init() {}
    
    public func startMonitoring() {
        refCount += 1
        if refCount == 1 {
            isRunning = true
            startNettop()
        }
    }
    
    public func stopMonitoring() {
        refCount = max(0, refCount - 1)
        if refCount == 0 {
            cleanupMonitoringResources()
        }
    }
    
    private func startNettop() {
        #if os(macOS)
        let task = Process()
        task.launchPath = "/usr/bin/nettop"
        // -P: collapse rows to parent process
        // -L 0: loop forever
        // -J: include columns (bytes_in, bytes_out)
        // -d: delta mode (print difference since last update)
        // -x: extended format (machine readable)
        task.arguments = ["-P", "-L", "0", "-J", "bytes_in,bytes_out", "-d", "-x"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        self.outputPipe = pipe
        self.task = task
        
        pipe.fileHandleForReading.waitForDataInBackgroundAndNotify()

        // Listen for data output
        dataAvailableObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable, object: pipe.fileHandleForReading, queue: nil) { [weak self, weak pipe] _ in
            guard let pipe else { return }
            let output = pipe.fileHandleForReading.availableData
            // Hop to main actor to process output
            Task { @MainActor [weak self, weak pipe] in
                guard let self, let pipe, self.isRunning, self.outputPipe === pipe else { return }
                if !output.isEmpty {
                    self.processOutput(output)
                }
                pipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
            }
        }
        
        do {
            try task.run()
            if Self.verbose {
                if NetworkManagerPlugin.verbose {
                                    NetworkManagerPlugin.logger.info("\(self.t)nettop process started")
                }
            }
        } catch {
            if NetworkManagerPlugin.verbose {
                            NetworkManagerPlugin.logger.error("\(self.t)Failed to start nettop: \(error.localizedDescription)")
            }
            refCount = 0
            cleanupMonitoringResources()
        }
        #else
        // Linux implementation would go here (using /proc/net/tcp, etc.)
        if NetworkManagerPlugin.verbose {
                    NetworkManagerPlugin.logger.error("\(self.t)Process monitoring not supported on this OS")
        }
        #endif
    }

    private func cleanupMonitoringResources() {
        isRunning = false
        if Self.verbose, NetworkManagerPlugin.verbose {
            NetworkManagerPlugin.logger.info("\(self.t)清理 nettop 监控资源（终止子进程 + 移除观察者）")
        }

        if let dataAvailableObserver {
            NotificationCenter.default.removeObserver(dataAvailableObserver)
            self.dataAvailableObserver = nil
        }

        bufferTimer?.invalidate()
        bufferTimer = nil

        task?.terminate()
        task = nil

        outputPipe?.fileHandleForReading.closeFile()
        outputPipe = nil

        rawDataBuffer.removeAll()
        partialLine = ""
        historyBuffer.removeAll()
        processDetails.removeAll()
        processes.removeAll()
    }
    
    // Buffering related
    private var rawDataBuffer: [RawProcessData] = []
    private var bufferTimer: Timer?
    private var partialLine = ""
    
    private func processOutput(_ data: Data) {
        guard let string = String(data: data, encoding: .utf8) else { return }

        let fullString = partialLine + string
        let lines = fullString.components(separatedBy: .newlines)

        if let last = lines.last, !string.hasSuffix("\n") {
            partialLine = last
        } else {
            partialLine = ""
        }

        // 节流心跳：nettop -L 0 持续输出，确认本回调是否高频触发（100% CPU 的可能来源）。
        tickCount += 1
        if Self.verbose, tickCount % tickLogEvery == 0 {
            let tick = tickCount
            let lineCount = lines.count
            NetworkManagerPlugin.logger.info("\(self.t)tick #\(tick) 解析 nettop 输出，\(lineCount) 行")
        }
        
        for line in lines.dropLast() {
            // Skip Header or empty lines
            if line.contains("bytes_in") || line.isEmpty { continue }
            
            let components = line.components(separatedBy: ",")
            
            // nettop -P -L 0 -J bytes_in,bytes_out -d -x Output format:
            // process.pid,bytes_in,bytes_out,
            // Note: There might be a trailing comma leading to empty string
            
            if components.count >= 3 {
                let namePart = components[0]
                guard !namePart.isEmpty else { continue }
                
                // Try parsing
                // components[1] -> bytes_in
                // components[2] -> bytes_out
                
                if let bytesIn = Double(components[1]),
                   let bytesOut = Double(components[2]) {
                    
                    let nameComponents = namePart.components(separatedBy: ".")
                    if let pidStr = nameComponents.last, let pid = Int(pidStr) {
                        let name = nameComponents.dropLast().joined(separator: ".")
                        rawDataBuffer.append(RawProcessData(pid: pid, name: name, bytesIn: bytesIn, bytesOut: bytesOut))
                    }
                }
            }
        }
        
        // Reset debounce timer
        bufferTimer?.invalidate()
        bufferTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.flushBuffer()
            }
        }
    }
    
    private func flushBuffer() {
        guard !rawDataBuffer.isEmpty else { return }
        aggregateAndPublish(rawDataBuffer)
        rawDataBuffer.removeAll()
    }
    
    struct RawProcessData {
        let pid: Int
        let name: String
        let bytesIn: Double
        let bytesOut: Double
    }
    
    private func aggregateAndPublish(_ rawData: [RawProcessData]) {
        // 1. Aggregate multi-instances (by name)
        // Requirement: If multiple instances of the same process name appear, fold them into one record and accumulate bandwidth
        // But do we need to keep PID? If aggregated, PID can be the main PID or -1.
        // User requirements say "Table columns: icon, name, PID...", if aggregated, what to show for PID?
        // Usually show "Multi-instance" or main process PID.
        // Here we aggregate by Name, and take the largest PID (usually the latest started) or the first one.
        
        var aggregated: [String: (pid: Int, bytesIn: Double, bytesOut: Double)] = [:]
        
        // Collect new PIDs that need icon fetching
        var newPIDs: [(pid: Int, name: String)] = []

        for item in rawData {
            if let existing = aggregated[item.name] {
                aggregated[item.name] = (existing.pid, existing.bytesIn + item.bytesIn, existing.bytesOut + item.bytesOut)
            } else {
                aggregated[item.name] = (item.pid, item.bytesIn, item.bytesOut)
            }

            // Collect new PIDs for background icon fetching
            if processDetails[item.pid] == nil {
                newPIDs.append((item.pid, item.name))
            }
        }

        // Fetch icons in background
        if !newPIDs.isEmpty {
            iconQueue.async { [weak self] in
                var fetchedIcons: [(pid: Int, name: String, icon: NSImage?)] = []
                for item in newPIDs {
                    let icon = NSRunningApplication(processIdentifier: pid_t(item.pid))?.icon
                        ?? NSWorkspace.shared.icon(forFile: "/bin/bash") // Fallback
                    fetchedIcons.append((item.pid, item.name, icon))
                }

                // Update cache on main thread
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    for item in fetchedIcons {
                        self.processDetails[item.pid] = (item.name, item.icon)
                    }
                }
            }
        }
        
        // 2. Simple Moving Average (SMA)
        var resultProcesses: [NetworkProcess] = []
        
        for (name, data) in aggregated {
            let pid = data.pid
            
            // Get history data
            var history = historyBuffer[name] ?? []
            
            // Add new data point
            history.append((data.bytesIn, data.bytesOut))
            
            // Maintain window size
            if history.count > smoothingWindow {
                history.removeFirst()
            }
            
            // 更新缓存
            historyBuffer[name] = history
            
            // 计算平均值
            let totalIn = history.reduce(0.0) { $0 + $1.0 }
            let totalOut = history.reduce(0.0) { $0 + $1.1 }
            let avgIn = totalIn / Double(history.count)
            let avgOut = totalOut / Double(history.count)
            
            // 只有当速度 > 0 才创建记录，或者为了列表稳定，保留最近活跃的
            if avgIn > 0 || avgOut > 0 {
                let icon = processDetails[pid]?.icon
                let process = NetworkProcess(
                    id: pid,
                    name: name,
                    icon: icon,
                    downloadSpeed: avgIn,
                    uploadSpeed: avgOut,
                    timestamp: Date()
                )
                resultProcesses.append(process)
            }
        }
        
        // 清理过期的历史数据 (可选：移除不再活跃的进程)
        // 简单策略：如果 name 不在本次 aggregated 中，可以从 historyBuffer 移除，
        // 但为了防止闪烁，可以保留一会儿。这里暂时简单处理：仅保留本次有的。
        // 为了性能，我们可以定期清理，或者直接在这里重建 buffer（不推荐，因为要保留历史）。
        // 修正策略：historyBuffer 应该只保留最近活跃的。
        // 遍历 historyBuffer 的 keys，如果不在 aggregated 中，移除。
        for key in historyBuffer.keys {
            if aggregated[key] == nil {
                historyBuffer.removeValue(forKey: key)
            }
        }
        
        // 回调
        if !resultProcesses.isEmpty {
            if Self.verbose {
                if NetworkManagerPlugin.verbose {
                                    NetworkManagerPlugin.logger.info("\(self.t)Published \(resultProcesses.count) processes")
                }
            }
        }
        
        DispatchQueue.main.async {
            self.processes = resultProcesses
        }
    }
    
    // private var smoothedSpeeds: [String: (in: Double, out: Double)] = [:] // 已移除，改用 historyBuffer
}
