import Foundation
import AppKit
import Combine
import OSLog
import MagicKit

@MainActor
class ProcessMonitorService: ObservableObject, SuperLog {
    static let shared = ProcessMonitorService()
    nonisolated static let emoji = "🕵️‍♂️"
    
    // 采样间隔
    private let interval: TimeInterval = 1.0
    
    // 3点滑动平均队列
    private var historyBuffer: [String: [(Double, Double)]] = [:] // Name -> [(In, Out)]
    private let smoothingWindow = 3
    
    // 进程信息缓存
    private var processDetails: [Int: (name: String, icon: NSImage?)] = [:]
    
    // 运行状态
    private var isRunning = false
    private var refCount = 0
    private var task: Process?
    private var outputPipe: Pipe?
    
    // 数据发布
    @Published var processes: [NetworkProcess] = []
    
    private init() {}
    
    func startMonitoring() {
        refCount += 1
        if refCount == 1 {
            isRunning = true
            startNettop()
        }
    }
    
    func stopMonitoring() {
        refCount = max(0, refCount - 1)
        if refCount == 0 {
            isRunning = false
            task?.terminate()
            task = nil
            historyBuffer.removeAll()
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
        
        // 监听数据输出
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable, object: pipe.fileHandleForReading, queue: nil) { [weak self] notification in
            guard let self = self, self.isRunning else { return }
            
            let output = pipe.fileHandleForReading.availableData
            if !output.isEmpty {
                self.processOutput(output)
            }
            
            pipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        }
        
        do {
            try task.run()
            os_log("\(self.t)nettop process started")
        } catch {
            os_log(.error, "\(self.t)Failed to start nettop: \(error.localizedDescription)")
            self.isRunning = false
        }
        #else
        // Linux implementation would go here (using /proc/net/tcp, etc.)
        os_log(.error, "\(self.t)Process monitoring not supported on this OS")
        #endif
    }
    
    // 缓冲相关
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
        
        for line in lines.dropLast() {
            // 跳过 Header 或空行
            if line.contains("bytes_in") || line.isEmpty { continue }
            
            let components = line.components(separatedBy: ",")
            
            // nettop -P -L 0 -J bytes_in,bytes_out -d -x 输出格式:
            // process.pid,bytes_in,bytes_out,
            // 注意末尾可能有逗号导致空字符串
            
            if components.count >= 3 {
                let namePart = components[0]
                guard !namePart.isEmpty else { continue }
                
                // 尝试解析
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
        
        // 重置防抖 Timer
        bufferTimer?.invalidate()
        bufferTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            self?.flushBuffer()
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
        // 1. 聚合多实例 (按名称聚合)
        // 需求：若同一进程名出现多实例，自动折叠为一条记录，带宽累加
        // 但我们需要保留 PID 吗？如果是聚合后的，PID 可以是其中一个的主 PID 或者 -1
        // 用户需求里说 "表格列：进程图标、进程名、PID..."，如果聚合了，PID 显示什么？
        // 通常显示 "多实例" 或者主进程 PID。
        // 这里我们按 (Name) 聚合，PID 取最大的那个（通常是最近启动的）或者第一个。
        
        var aggregated: [String: (pid: Int, bytesIn: Double, bytesOut: Double)] = [:]
        
        for item in rawData {
            if let existing = aggregated[item.name] {
                aggregated[item.name] = (existing.pid, existing.bytesIn + item.bytesIn, existing.bytesOut + item.bytesOut)
            } else {
                aggregated[item.name] = (item.pid, item.bytesIn, item.bytesOut)
            }
            
            // 缓存图标
            if processDetails[item.pid] == nil {
                let icon = NSRunningApplication(processIdentifier: pid_t(item.pid))?.icon 
                    ?? NSWorkspace.shared.icon(forFile: "/bin/bash") // Fallback
                processDetails[item.pid] = (item.name, icon)
            }
        }
        
        // 2. 滑动平均 (SMA - Simple Moving Average)
        var resultProcesses: [NetworkProcess] = []
        
        for (name, data) in aggregated {
            let pid = data.pid
            
            // 获取历史数据
            var history = historyBuffer[name] ?? []
            
            // 添加新数据点
            history.append((data.bytesIn, data.bytesOut))
            
            // 保持窗口大小
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
            os_log("\(self.t)Published \(resultProcesses.count) processes")
        }
        
        DispatchQueue.main.async {
            self.processes = resultProcesses
        }
    }
    
    // private var smoothedSpeeds: [String: (in: Double, out: Double)] = [:] // 已移除，改用 historyBuffer
}
