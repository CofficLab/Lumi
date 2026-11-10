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
    nonisolated static let samplingInterval: TimeInterval = 1.0
    private var interval: TimeInterval { Self.samplingInterval }
    
    // 3-point moving average queue
    private var historyBuffer: [String: [(Double, Double)]] = [:] // Name -> [(In, Out)]
    private let smoothingWindow = 3
    
    // Process info cache
    private var processDetails: [Int: (name: String, icon: NSImage?)] = [:]

    /// 已经出现过至少一次的 PID。
    ///
    /// nettop `-d` 的首帧对每个进程输出的是累计值（自进程启动以来），
    /// 而不是本采样周期内的 delta。首帧必须丢弃，否则历史累计字节会被
    /// 当成「1 秒速度」，并被移动平均保留数秒。
    private var seenPIDs: Set<Int> = []

    /// 当前 nettop 采样帧序号。
    ///
    /// nettop 每个采样周期输出一次表头；一次 flush 可能合并多帧，
    /// 需要用帧数还原每段 delta 实际覆盖的采样跨度。
    private var frameIndex = 0

    /// 图标解析器。
    ///
    /// - Note: 走 `bundleIdentifier` 缓存 + `NSWorkspace.icon(forFile:)`，
    ///   避开逐 PID 构造 `NSRunningApplication` 触发的 LaunchServices 同步 XPC。
    private nonisolated let iconResolver = ProcessIconResolver()

    /// 进程名补全器：nettop 的进程名会截断到 15 字符，按 PID 补全为完整可执行文件名。
    private var nameResolver: ProcessNameResolver

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

    /// 是否已经发布过至少一个有效的周期 delta。
    ///
    /// nettop 启动后的首帧累计值会被丢弃，在第一次有效发布之前，
    /// UI 应显示「收集数据中」而不是「没有活跃进程」。
    @Published public private(set) var hasPublishedSample = false

    /// 启动 nettop 子进程的方式。
    ///
    /// - Note: 仅为测试可注入而存在；生产环境使用默认实现。
    private let nettopLauncher: () -> Process?

    private init(
        nettopLauncher: (() -> Process?)? = nil,
        nameProvider: ProcessNameResolver.NameProvider? = nil
    ) {
        self.nettopLauncher = nettopLauncher ?? { ProcessMonitorService.makeDefaultNettopProcess() }
        if let nameProvider {
            self.nameResolver = ProcessNameResolver(nameProvider: nameProvider)
        } else {
            self.nameResolver = ProcessNameResolver()
        }
    }

    /// 创建一个不启动真实 nettop 子进程的实例（仅测试用）。
    ///
    /// - Parameters:
    ///   - launcher: 子进程构造器；返回 `nil` 表示模拟「启动失败」。
    ///   - nameProvider: 进程名解析器，仅测试可注入，生产环境默认按 PID 读取可执行文件路径。
    static func makeForTesting(
        nettopLauncher: @escaping () -> Process?,
        nameProvider: ProcessNameResolver.NameProvider? = nil
    ) -> ProcessMonitorService {
        ProcessMonitorService(nettopLauncher: nettopLauncher, nameProvider: nameProvider)
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
        seenPIDs.removeAll()
        frameIndex = 0
        nameResolver.removeAll()
        iconResolver.clearCache()
        processes.removeAll()
        hasPublishedSample = false
    }
    
    // Buffering related
    private var rawDataBuffer: [RawProcessData] = []
    private var bufferTimer: Timer?
    private var partialLine = ""
    
    func processOutput(_ data: Data) {
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
            // 每帧表头出现一次：据此递增帧序号，用于归一化跨帧合并的 delta。
            if line.contains("bytes_in") {
                frameIndex += 1
                continue
            }
            if line.isEmpty { continue }
            
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
                        // 丢弃每个 PID 的首帧累计值，只接受后续的周期 delta。
                        if seenPIDs.insert(pid).inserted {
                            continue
                        }

                        let fallbackName = nameComponents.dropLast().joined(separator: ".")
                        let displayName = nameResolver.resolve(pid: pid, fallback: fallbackName)
                        rawDataBuffer.append(RawProcessData(
                            pid: pid,
                            name: displayName,
                            bytesIn: bytesIn,
                            bytesOut: bytesOut,
                            frameIndex: frameIndex
                        ))
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
    
    func flushBuffer() {
        guard !rawDataBuffer.isEmpty else { return }
        aggregateAndPublish(rawDataBuffer)
        rawDataBuffer.removeAll()
    }
    
    struct RawProcessData {
        let pid: Int
        let name: String
        let bytesIn: Double
        let bytesOut: Double
        /// 该行所属的 nettop 采样帧序号。
        let frameIndex: Int
    }

    /// 按进程名聚合，并把每个 PID 的整段 delta 归一化到实际覆盖的采样跨度。
    ///
    /// 正常情况下一次 flush 只含一帧（1 秒）；若主线程繁忙导致一次 flush 合并了
    /// 多帧，同一 PID 的 delta 会覆盖多秒。这里用该 PID 在本批次出现的帧数还原
    /// 速率，避免「单次 flush 合并多个采样」造成流量高估。
    ///
    /// 已知限制：若 nettop 对某个 PID 重新输出的首行又退回累计值（例如进程短暂
    /// 从输出中消失后再次出现），本批次无法识别，该进程速率可能失真；本地无法
    /// 稳定复现该场景，因此未做额外处理，记录为已知限制。
    private func aggregateAndPublish(_ rawData: [RawProcessData]) {
        // 1. 先按 PID 汇总：记录该 PID 覆盖的帧集合与总字节。
        struct PIDSample {
            var name: String
            var frames: Set<Int>
            var bytesIn: Double
            var bytesOut: Double
        }

        var perPID: [Int: PIDSample] = [:]

        // 收集需要取图标的新 PID；以 PID 去重，避免同一批次里重复入队。
        var newPIDs: [Int: String] = [:]

        for item in rawData {
            if var sample = perPID[item.pid] {
                sample.bytesIn += item.bytesIn
                sample.bytesOut += item.bytesOut
                sample.frames.insert(item.frameIndex)
                perPID[item.pid] = sample
            } else {
                perPID[item.pid] = PIDSample(
                    name: item.name,
                    frames: [item.frameIndex],
                    bytesIn: item.bytesIn,
                    bytesOut: item.bytesOut
                )
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
        
        // 2. 归一化到采样跨度：frames.count 个 delta 覆盖 frames.count × interval 秒。
        var aggregated: [String: (pid: Int, download: Double, upload: Double, count: Int, icon: NSImage?, isCurrentApp: Bool)] = [:]
        let selfPID = Int(getpid())

        for (pid, sample) in perPID {
            let coveredFrames = max(sample.frames.count, 1)
            let coverageSeconds = Double(coveredFrames) * interval
            let download = sample.bytesIn / coverageSeconds
            let upload = sample.bytesOut / coverageSeconds
            let icon = processDetails[pid]?.icon
            let isSelf = pid == selfPID

            if var existing = aggregated[sample.name] {
                existing.download += download
                existing.upload += upload
                existing.count += 1
                existing.pid = min(existing.pid, pid)
                if existing.icon == nil { existing.icon = icon }
                existing.isCurrentApp = existing.isCurrentApp || isSelf
                aggregated[sample.name] = existing
            } else {
                aggregated[sample.name] = (pid, download, upload, 1, icon, isSelf)
            }
        }

        // 3. 平滑只作用于展示值：首帧立即发布（按已有样本取均值），不额外等待。
        var resultProcesses: [NetworkProcess] = []
        
        for (name, data) in aggregated {
            // Get history data
            var history = historyBuffer[name] ?? []
            
            // Add new data point
            history.append((data.download, data.upload))
            
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
                let process = NetworkProcess(
                    id: data.pid,
                    name: name,
                    icon: data.icon,
                    downloadSpeed: avgIn,
                    uploadSpeed: avgOut,
                    timestamp: Date(),
                    instanceCount: data.count,
                    isCurrentApp: data.isCurrentApp
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
            self.hasPublishedSample = true
        }
    }
    
    // private var smoothedSpeeds: [String: (in: Double, out: Double)] = [:] // 已移除，改用 historyBuffer
}
