import Foundation
import LumiLoggingKit
import AppKit
import Combine

@MainActor
public class ProcessMonitorService: ObservableObject, SuperLog {
    public static let shared = ProcessMonitorService()
    public nonisolated static let emoji = "👮"
    public nonisolated static let verbose: Bool = false
    
    // Sampling interval
    private let interval: TimeInterval = 1.0
    
    // 3-point moving average queue
    private var historyBuffer: [String: [(Double, Double)]] = [:] // Name -> [(In, Out)]
    private let smoothingWindow = 3
    
    // Process info cache
    private var processDetails: [Int: (name: String, icon: NSImage?)] = [:]

    /// 图标解析器。
    ///
    /// - Note: 走 `bundleIdentifier` 缓存 + `NSWorkspace.icon(forFile:)`，
    ///   避开逐 PID 构造 `NSRunningApplication` 触发的 LaunchServices 同步 XPC。
    private nonisolated let iconResolver = ProcessIconResolver()

    // Background queue for icon fetching
    private let iconQueue = DispatchQueue(label: "com.coffic.lumi.process-icons", qos: .utility)
    
    // Runtime status
    private var isRunning = false
    private var refCount = 0
    private var task: Process?
    private var outputPipe: Pipe?
    /// nettop 的 stdin 管道。
    ///
    /// - Important: 父进程必须一直持有写端且永不写入。nettop 会轮询 stdin，
    ///   若 stdin 是 `/dev/null` 或已关闭的管道，`-L 0` 会退化成忙循环并占用 100%+ CPU。
    private(set) var inputPipe: Pipe?
    private var dataAvailableObserver: NSObjectProtocol?

    /// 心跳节流计数：nettop 子进程(-L 0 永久循环)每次输出回调自增，每 N 次打一条。
    /// nettop 会高频持续产出数据，若本回调狂触发是 100% CPU 的直接信号。
    private var tickCount = 0
    private let tickLogEvery = 20
    
    // Data publishing
    @Published var processes: [NetworkProcess] = []

    /// 启动 nettop 子进程的方式。
    ///
    /// - Note: 仅为测试可注入而存在；生产环境使用默认实现。
    private let nettopLauncher: () -> Process?

    private init(nettopLauncher: (() -> Process?)? = nil) {
        self.nettopLauncher = nettopLauncher ?? { ProcessMonitorService.makeDefaultNettopProcess() }
    }

    /// 创建一个不启动真实 nettop 子进程的实例（仅测试用）。
    ///
    /// - Parameter launcher: 子进程构造器；返回 `nil` 表示模拟「启动失败」。
    static func makeForTesting(nettopLauncher: @escaping () -> Process?) -> ProcessMonitorService {
        ProcessMonitorService(nettopLauncher: nettopLauncher)
    }

    /// 当前 nettop 子进程是否在运行。
    var isNettopRunning: Bool { task != nil }

    /// 默认的 nettop 进程构造。
    static func makeDefaultNettopProcess() -> Process? {
        #if os(macOS)
        let task = Process()
        task.launchPath = "/usr/bin/nettop"
        // -P: collapse rows to parent process
        // -L 0: loop forever
        // -J: include columns (bytes_in, bytes_out)
        // -d: delta mode (print difference since last update)
        // -x: extended format (machine readable)
        // -n: 不做地址反查，避免每个采样周期的 DNS 查询
        // -s 1: 每秒采样一次
        task.arguments = ["-P", "-L", "0", "-J", "bytes_in,bytes_out", "-d", "-x", "-n", "-s", "1"]

        // nettop 在 stdout 非 TTY 时使用块缓冲，4 KB 才 flush 一次，导致数据
        // 每 4~5 秒才批量到达。`NSUnbufferedIO` 让每次采样立即写出。
        var environment = ProcessInfo.processInfo.environment
        environment["NSUnbufferedIO"] = "YES"
        task.environment = environment
        return task
        #else
        return nil
        #endif
    }
    
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
        guard let task = nettopLauncher() else {
            if NetworkManagerPlugin.verbose {
                NetworkManagerPlugin.logger.error("\(self.t)nettop unavailable")
            }
            refCount = 0
            cleanupMonitoringResources()
            return
        }

        let pipe = Pipe()
        task.standardOutput = pipe
        self.outputPipe = pipe

        // 父进程持有写端且永不写入：nettop 读 stdin 时会阻塞而不是空转。
        let inputPipe = Pipe()
        task.standardInput = inputPipe
        self.inputPipe = inputPipe

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

        // 只终止**确实在运行**的子进程。
        //
        // - Important: `Process.terminate()` 对未成功启动的进程会抛 ObjC 异常
        //   （NSInvalidArgumentException），进而使 App 崩溃。
        //   nettop 启动失败时（路径不存在、无权限等）会走到这里，必须先判断。
        if let task, task.isRunning {
            task.terminate()
        }
        task = nil

        // 必须先 terminate 再关闭 stdin：
        // 若先关闭写端，nettop 会在 stdin EOF 上重新忙循环，直到进程退出。
        if let inputPipe {
            self.inputPipe = nil
            inputPipe.fileHandleForReading.closeFile()
            inputPipe.fileHandleForWriting.closeFile()
        }

        // 确定性回收 nettop 管道的读端 fd（写端由子进程持有，随进程退出释放）。
        // 关闭已关闭的文件同样会抛异常，故先置空再关闭，保证幂等。
        if let pipe = outputPipe {
            outputPipe = nil
            pipe.fileHandleForReading.closeFile()
        }

        rawDataBuffer.removeAll()
        partialLine = ""
        historyBuffer.removeAll()
        processDetails.removeAll()
        iconResolver.clearCache()
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
        
        // 收集需要取图标的新 PID；以 PID 去重，避免同一批次里重复入队。
        var newPIDs: [Int: String] = [:]

        for item in rawData {
            if let existing = aggregated[item.name] {
                aggregated[item.name] = (existing.pid, existing.bytesIn + item.bytesIn, existing.bytesOut + item.bytesOut)
            } else {
                aggregated[item.name] = (item.pid, item.bytesIn, item.bytesOut)
            }

            // PID 被系统回收后可能对应新进程：名称不一致时视为缓存失效。
            if processDetails[item.pid]?.name != item.name {
                newPIDs[item.pid] = item.name
                // 先清掉旧图标，避免这一帧复用已失效的 PID 图标。
                processDetails[item.pid] = (item.name, nil)
            }
        }

        // 本轮未出现的进程详情直接剔除，避免字典增长与 PID 复用残留。
        let livePIDs = Set(rawData.map(\.pid))
        processDetails = processDetails.filter { livePIDs.contains($0.key) }

        // 一次批量枚举 runningApplications，再按 PID 分发图标。
        if !newPIDs.isEmpty {
            // 用不可变快照跨线程传递，避免可变字典同时被后台与主线程闭包捕获。
            let iconNames = newPIDs
            let pidsToFetch = Array(iconNames.keys)
            let resolver = iconResolver

            iconQueue.async { [weak self] in
                let icons = resolver.icons(forPIDs: pidsToFetch)

                // Update cache on main thread
                Task { @MainActor in
                    guard let self else { return }
                    for (pid, icon) in icons {
                        // 异步结果返回时进程可能已退出或 PID 已被复用，丢弃过期结果。
                        guard let name = iconNames[pid],
                              self.processDetails[pid]?.name == name else { continue }
                        self.processDetails[pid] = (name, icon)
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
        
        // 剔除本轮未出现的进程历史，避免长期运行时字典增长。
        historyBuffer = historyBuffer.filter { aggregated[$0.key] != nil }
        
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
