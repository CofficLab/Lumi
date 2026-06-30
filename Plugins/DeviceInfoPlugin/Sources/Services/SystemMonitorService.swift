import Foundation
import Combine
import IOKit
import SuperLogKit
import os

private final class MonitorState: @unchecked Sendable {
    var timer: Timer?
    var cpuInfo: processor_info_array_t?
    var numCpuInfo: mach_msg_type_number_t = 0
    var prevCpuInfo: processor_info_array_t?
    var prevNumCpuInfo: mach_msg_type_number_t = 0

    deinit {
        timer?.invalidate()

        if let info = cpuInfo {
            let size = Int(numCpuInfo) * MemoryLayout<integer_t>.size
            let ptr = UnsafeMutableRawPointer(info)
            vm_deallocate(mach_task_self_, vm_address_t(Int(bitPattern: ptr)), vm_size_t(size))
        }
        if let info = prevCpuInfo {
            let size = Int(prevNumCpuInfo) * MemoryLayout<integer_t>.size
            let ptr = UnsafeMutableRawPointer(info)
            vm_deallocate(mach_task_self_, vm_address_t(Int(bitPattern: ptr)), vm_size_t(size))
        }
    }
}

/// Comprehensive system monitor service that tracks CPU, memory, network, and disk metrics.
@MainActor
public final class SystemMonitorService: ObservableObject, SuperLog {
    public static let shared = SystemMonitorService()
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "devicemonitor.system")
    nonisolated public static let emoji = "📊"

    @Published public var currentMetrics: SystemMetrics = .empty

    private nonisolated let state = MonitorState()

    // Previous states for delta calculation
    private var prevNetworkIn: UInt64 = 0
    private var prevNetworkOut: UInt64 = 0
    private var prevDiskRead: UInt64 = 0
    private var prevDiskWrite: UInt64 = 0
    private var lastCheckTime: TimeInterval = 0
    private var lastDiskCheckTime: TimeInterval = 0

    // History buffers (keep last 60 points)
    private var cpuHistory: [Double] = Array(repeating: 0, count: 60)
    private var memoryHistory: [Double] = Array(repeating: 0, count: 60)
    private var netInHistory: [Double] = Array(repeating: 0, count: 60)
    private var netOutHistory: [Double] = Array(repeating: 0, count: 60)
    private var diskReadHistory: [Double] = Array(repeating: 0, count: 60)
    private var diskWriteHistory: [Double] = Array(repeating: 0, count: 60)

    // CPU load info
    private var numCPUs: natural_t = 0
    private var refCount = 0
    private var samplingTask: Task<Void, Never>?
    private let diskCountersProvider: (@MainActor () -> (readBytes: UInt64, writeBytes: UInt64)?)?
    private let diskCountersReader: @Sendable () -> (readBytes: UInt64, writeBytes: UInt64)?
    private let timeProvider: @MainActor () -> TimeInterval
    private let diskCounterInterval: TimeInterval
    private var lastDiskSampleRequestTime: TimeInterval = 0

    package init(
        diskCountersProvider: (@MainActor () -> (readBytes: UInt64, writeBytes: UInt64)?)? = nil,
        diskCountersReader: @escaping @Sendable () -> (readBytes: UInt64, writeBytes: UInt64)? = {
            SystemMonitorService.readDiskCounters()
        },
        diskCounterInterval: TimeInterval = 5,
        timeProvider: @escaping @MainActor () -> TimeInterval = {
            Date().timeIntervalSince1970
        }
    ) {
        self.diskCountersProvider = diskCountersProvider
        self.diskCountersReader = diskCountersReader
        self.diskCounterInterval = diskCounterInterval
        self.timeProvider = timeProvider

        var mib = [CTL_HW, HW_NCPU]
        var sizeOfNumCPUs = MemoryLayout<natural_t>.size
        sysctl(&mib, 2, &numCPUs, &sizeOfNumCPUs, nil, 0)
    }

    // MARK: - Public Methods

    public func startMonitoring() {
        refCount += 1
        if refCount == 1 {
            startTimer()
        }
    }

    public func stopMonitoring(force: Bool = false) {
        if force {
            refCount = 0
        } else if refCount > 0 {
            refCount -= 1
        }

        if refCount == 0 {
            stopTimer()
        }
    }

    // MARK: - Private Methods

    private func startTimer() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleMetricsUpdate()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        state.timer = timer
        updateMetrics(diskCounters: nil)
        scheduleMetricsUpdate()
    }

    private func stopTimer() {
        state.timer?.invalidate()
        state.timer = nil
        samplingTask?.cancel()
        samplingTask = nil
    }

    private func scheduleMetricsUpdate() {
        if let diskCountersProvider {
            updateMetrics(diskCounters: diskCountersProvider())
            return
        }

        // Move CPU, memory, network sampling to background
        guard samplingTask == nil else { return }

        samplingTask = Task.detached(priority: .utility) { [weak self] in
            // 采集数据在后台线程
            let cpu = Self.sampleCPUUsage()
            let (memUsed, memTotal) = Self.sampleMemoryUsage()
            let (netIn, netOut) = Self.sampleNetworkUsage()

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.samplingTask = nil
                guard self.refCount > 0 else { return }
                self.updateMetrics(cpu: cpu, memUsed: memUsed, memTotal: memTotal, netIn: netIn, netOut: netOut, diskCounters: nil)
            }
        }
    }

    private func scheduleDiskCountersUpdateIfNeeded() {
        let now = timeProvider()
        guard samplingTask == nil else { return }
        guard lastDiskSampleRequestTime == 0 || now - lastDiskSampleRequestTime >= diskCounterInterval else { return }

        lastDiskSampleRequestTime = now
        let diskCountersReader = diskCountersReader
        samplingTask = Task.detached(priority: .utility) { [weak self] in
            let diskCounters = diskCountersReader()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.samplingTask = nil
                guard self.refCount > 0 else { return }
                self.updateMetrics(diskCounters: diskCounters)
            }
        }
    }

    private func updateMetrics(diskCounters: (readBytes: UInt64, writeBytes: UInt64)?) {
        let cpu = getCPUUsage()
        let (memUsed, memTotal) = getMemoryUsage()
        let (netIn, netOut) = getNetworkUsage()
        let (diskRead, diskWrite) = getDiskUsage(counters: diskCounters)

        updateMetrics(cpu: cpu, memUsed: memUsed, memTotal: memTotal, netIn: netIn, netOut: netOut, diskCounters: diskCounters)
    }

    private func updateMetrics(cpu: Double, memUsed: UInt64, memTotal: UInt64, netIn: Double, netOut: Double, diskCounters: (readBytes: UInt64, writeBytes: UInt64)?) {
        let (diskRead, diskWrite) = getDiskUsage(counters: diskCounters)

        cpuHistory = (cpuHistory.dropFirst() + [cpu]).suffix(60)
        memoryHistory = (memoryHistory.dropFirst() + [Double(memUsed) / Double(memTotal)]).suffix(60)
        netInHistory = (netInHistory.dropFirst() + [netIn]).suffix(60)
        netOutHistory = (netOutHistory.dropFirst() + [netOut]).suffix(60)
        diskReadHistory = (diskReadHistory.dropFirst() + [diskRead]).suffix(60)
        diskWriteHistory = (diskWriteHistory.dropFirst() + [diskWrite]).suffix(60)

        let metrics = SystemMetrics(
            timestamp: Date(),
            cpuUsage: ResourceUsage(
                percentage: cpu,
                description: String(format: "%.1f%%", cpu * 100),
                history: cpuHistory
            ),
            memoryUsage: ResourceUsage(
                percentage: Double(memUsed) / Double(memTotal),
                description: ByteCountFormatter.string(fromByteCount: Int64(memUsed), countStyle: .memory),
                history: memoryHistory
            ),
            network: NetworkMetrics(
                uploadSpeed: netOut,
                downloadSpeed: netIn,
                uploadHistory: netOutHistory,
                downloadHistory: netInHistory
            ),
            disk: DiskMetrics(
                readSpeed: diskRead,
                writeSpeed: diskWrite,
                readHistory: diskReadHistory,
                writeHistory: diskWriteHistory
            )
        )

        currentMetrics = metrics
    }

    func refreshMetricsForTesting() {
        updateMetrics(diskCounters: diskCountersProvider?() ?? Self.readDiskCounters())
    }

    func refreshScheduledMetricsForTesting() {
        scheduleMetricsUpdate()
    }

    // MARK: - CPU Usage

    private func getCPUUsage() -> Double {
        var numCPUsU: natural_t = 0
        var cpuInfoU: processor_info_array_t?
        var numCpuInfoU: mach_msg_type_number_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUsU, &cpuInfoU, &numCpuInfoU)

        if result == KERN_SUCCESS {
            var totalUsage: Double = 0

            if let prevCpuInfo = state.prevCpuInfo {
                for i in 0..<Int32(numCPUs) {
                    var inUse: Int32 = 0
                    var total: Int32 = 0

                    let baseIndex = Int(i) * Int(CPU_STATE_MAX)

                    for j in 0..<Int(CPU_STATE_MAX) {
                        let current = cpuInfoU![baseIndex + j]
                        let prev = prevCpuInfo[baseIndex + j]
                        let diff = current - prev

                        total += diff

                        if j != Int(CPU_STATE_IDLE) {
                            inUse += diff
                        }
                    }

                    if total > 0 {
                        totalUsage += Double(inUse) / Double(total)
                    }
                }
                totalUsage /= Double(numCPUs)
            }

            if let prevInfo = state.prevCpuInfo {
                let size = Int(state.prevNumCpuInfo) * MemoryLayout<integer_t>.size
                let ptr = UnsafeMutableRawPointer(prevInfo)
                vm_deallocate(mach_task_self_, vm_address_t(Int(bitPattern: ptr)), vm_size_t(size))
            }

            state.prevCpuInfo = cpuInfoU
            state.prevNumCpuInfo = numCpuInfoU

            return totalUsage
        }

        return 0
    }

    // MARK: - Memory Usage

    private func getMemoryUsage() -> (used: UInt64, total: UInt64) {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var hostInfo = vm_statistics64_data_t()

        let result = withUnsafeMutablePointer(to: &hostInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }

        let total = ProcessInfo.processInfo.physicalMemory

        if result == KERN_SUCCESS {
            let pageSize = getKernelPageSize()
            let used = (UInt64(hostInfo.active_count) + UInt64(hostInfo.wire_count)) * pageSize
            return (used, total)
        }

        return (0, total)
    }

    // MARK: - Network Usage

    private func getNetworkUsage() -> (inBytes: Double, outBytes: Double) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var ptr = ifaddr
        while ptr != nil {
            let interface = ptr!.pointee
            let addressFamily = interface.ifa_addr?.pointee.sa_family
            if Self.shouldReadNetworkCounters(flags: interface.ifa_flags, addressFamily: addressFamily) {
                if let data = interface.ifa_data {
                    let stats = data.assumingMemoryBound(to: if_data.self).pointee
                    totalIn += UInt64(stats.ifi_ibytes)
                    totalOut += UInt64(stats.ifi_obytes)
                }
            }
            ptr = interface.ifa_next
        }

        let now = Date().timeIntervalSince1970
        let timeDiff = now - lastCheckTime

        var speedIn: Double = 0
        var speedOut: Double = 0

        if lastCheckTime > 0 && timeDiff > 0 {
            if totalIn >= prevNetworkIn {
                speedIn = Double(totalIn - prevNetworkIn) / timeDiff
            }
            if totalOut >= prevNetworkOut {
                speedOut = Double(totalOut - prevNetworkOut) / timeDiff
            }
        }

        prevNetworkIn = totalIn
        prevNetworkOut = totalOut
        lastCheckTime = now

        return (speedIn, speedOut)
    }

    package nonisolated static func shouldReadNetworkCounters(flags: UInt32, addressFamily: UInt8?) -> Bool {
        guard addressFamily == UInt8(AF_LINK) else { return false }
        guard (flags & UInt32(IFF_LOOPBACK)) == 0 else { return false }
        return (flags & UInt32(IFF_UP)) != 0
    }

    // MARK: - Disk Usage

    private func getDiskUsage(counters: (readBytes: UInt64, writeBytes: UInt64)?) -> (readBytes: Double, writeBytes: Double) {
        let now = timeProvider()
        guard let counters else {
            return (
                currentMetrics.disk.readSpeed,
                currentMetrics.disk.writeSpeed
            )
        }

        let timeDiff = now - lastDiskCheckTime
        var readSpeed: Double = 0
        var writeSpeed: Double = 0

        if lastDiskCheckTime > 0 && timeDiff > 0 {
            if counters.readBytes >= prevDiskRead {
                readSpeed = Double(counters.readBytes - prevDiskRead) / timeDiff
            }
            if counters.writeBytes >= prevDiskWrite {
                writeSpeed = Double(counters.writeBytes - prevDiskWrite) / timeDiff
            }
        }

        prevDiskRead = counters.readBytes
        prevDiskWrite = counters.writeBytes
        lastDiskCheckTime = now

        return (readSpeed, writeSpeed)
    }

    // MARK: - Helper

    private nonisolated func getKernelPageSize() -> UInt64 {
        var pageSize: vm_size_t = 0
        let result = host_page_size(mach_host_self(), &pageSize)
        return result == KERN_SUCCESS ? UInt64(pageSize) : 4096
    }

    private nonisolated static func readDiskCounters() -> (readBytes: UInt64, writeBytes: UInt64)? {
        var iterator: io_iterator_t = 0
        guard let matching = IOServiceMatching("IOBlockStorageDriver"),
              IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS
        else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0

        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            defer { IOObjectRelease(service) }

            var propertiesRef: Unmanaged<CFMutableDictionary>?
            let result = IORegistryEntryCreateCFProperties(service, &propertiesRef, kCFAllocatorDefault, 0)
            guard result == KERN_SUCCESS,
                  let properties = propertiesRef?.takeRetainedValue() as NSDictionary?,
                  let statistics = properties["Statistics"] as? NSDictionary
            else {
                continue
            }
            totalRead += uint64Value(statistics["Bytes (Read)"])
            totalWrite += uint64Value(statistics["Bytes (Write)"])
        }
        return (totalRead, totalWrite)
    }

    private nonisolated static func uint64Value(_ value: Any?) -> UInt64 {
        if let number = value as? NSNumber {
            return number.uint64Value
        }
        if let value = value as? UInt64 {
            return value
        }
        if let value = value as? Int64 {
            return UInt64(max(value, 0))
        }
        if let value = value as? Int {
            return UInt64(max(value, 0))
        }
        return 0
    }

    // MARK: - Static Sampling Methods (for background thread)

    /// 后台采样 CPU 使用率（无状态，每次独立采样）

    private nonisolated static func sampleCPUUsage() -> Double {
        var numCPUsU: natural_t = 0
        var cpuInfoU: processor_info_array_t?
        var numCpuInfoU: mach_msg_type_number_t = 0
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUsU, &cpuInfoU, &numCpuInfoU)

        guard result == KERN_SUCCESS, let cpuInfoU else { return 0 }

        // 简单采样：计算总体使用率（不依赖历史状态）

        var totalIdle: Int32 = 0
        var totalUsed: Int32 = 0
        for i in 0..<Int(numCPUsU) {
            let baseIndex = i * Int(CPU_STATE_MAX)
            for j in 0..<Int(CPU_STATE_MAX) {
                let value = cpuInfoU[baseIndex + j]
                if j == Int(CPU_STATE_IDLE) {
                    totalIdle += value
                } else {
                    totalUsed += value
                }
            }
        }

        // 释放内存

        let size = Int(numCpuInfoU) * MemoryLayout<integer_t>.size
        let ptr = UnsafeMutableRawPointer(cpuInfoU)
        vm_deallocate(mach_task_self_, vm_address_t(Int(bitPattern: ptr)), vm_size_t(size))

        let total = totalIdle + totalUsed
        return total > 0 ? Double(totalUsed) / Double(total) : 0
    }

    /// 后台采样内存使用情况

    private nonisolated static func sampleMemoryUsage() -> (used: UInt64, total: UInt64) {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var hostInfo = vm_statistics64_data_t()
        let result = withUnsafeMutablePointer(to: &hostInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }

        let total = ProcessInfo.processInfo.physicalMemory

        if result == KERN_SUCCESS {
            var pageSize: vm_size_t = 0
            host_page_size(mach_host_self(), &pageSize)
            let used = (UInt64(hostInfo.active_count) + UInt64(hostInfo.wire_count)) * UInt64(pageSize)
            return (used, total)
        }
        return (0, total)
    }

    /// 后台采样网络使用情况

    private nonisolated static func sampleNetworkUsage() -> (inBytes: Double, outBytes: Double) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var ptr = ifaddr
        while ptr != nil {
            let interface = ptr!.pointee
            let addressFamily = interface.ifa_addr?.pointee.sa_family
            if shouldReadNetworkCounters(flags: interface.ifa_flags, addressFamily: addressFamily) {
                if let data = interface.ifa_data {
                    let stats = data.assumingMemoryBound(to: if_data.self).pointee
                    totalIn += UInt64(stats.ifi_ibytes)
                    totalOut += UInt64(stats.ifi_obytes)
                }
            }
            ptr = interface.ifa_next
        }

        return (Double(totalIn), Double(totalOut))
    }
}
