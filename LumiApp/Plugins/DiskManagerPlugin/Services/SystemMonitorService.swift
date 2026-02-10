import Foundation
import Combine
import Darwin

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

@MainActor
class SystemMonitorService: ObservableObject {
    static let shared = SystemMonitorService()
    
    @Published var currentMetrics: SystemMetrics = .empty

    private nonisolated let state = MonitorState()
    
    // Previous states for delta calculation
    private var prevNetworkIn: UInt64 = 0
    private var prevNetworkOut: UInt64 = 0
    private var prevDiskRead: UInt64 = 0
    private var prevDiskWrite: UInt64 = 0
    private var lastCheckTime: TimeInterval = 0
    
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
    
    private init() {
        // Initialize CPU count
        var mib = [CTL_HW, HW_NCPU]
        var sizeOfNumCPUs = MemoryLayout<natural_t>.size
        sysctl(&mib, 2, &numCPUs, &sizeOfNumCPUs, nil, 0)
    }
    
    func startMonitoring() {
        refCount += 1
        if refCount == 1 {
            startTimer()
        }
    }

    func stopMonitoring(force: Bool = false) {
        if force {
            refCount = 0
        } else if refCount > 0 {
            refCount -= 1
        }

        if refCount == 0 {
            stopTimer()
        }
    }
    
    private func startTimer() {
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMetrics()
            }
        }
        state.timer = timer
        // Trigger immediately
        updateMetrics()
    }

    private func stopTimer() {
        state.timer?.invalidate()
        state.timer = nil
    }
    
    private func updateMetrics() {
        let cpu = getCPUUsage()
        let (memUsed, memTotal) = getMemoryUsage()
        let (netIn, netOut) = getNetworkUsage()
        // Disk I/O is tricky without root or complex IOKit, using simulation for now or simple heuristic if possible.
        // For now, let's use a placeholder or try to read simple stats if available.
        // Using a simple random simulation for Disk I/O demo as IOKit is complex for a simple plugin.
        // TODO: Implement real Disk I/O using IOKit
        let diskRead = Double.random(in: 0...1024*1024) // Simulated
        let diskWrite = Double.random(in: 0...512*1024) // Simulated

        // Update History
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

    // MARK: - Helper Methods

    /// Get kernel page size (using system API)
    private nonisolated func getKernelPageSize() -> UInt64 {
        var pageSize: vm_size_t = 0
        let result = host_page_size(mach_host_self(), &pageSize)
        return result == KERN_SUCCESS ? UInt64(pageSize) : 4096
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
            
            // Clean up previous
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
            // let name = String(cString: ptr!.pointee.ifa_name)  // Unused, commented out
            // Filter out loopback and non-active
            if (ptr!.pointee.ifa_flags & UInt32(IFF_LOOPBACK)) == 0 && (ptr!.pointee.ifa_flags & UInt32(IFF_UP)) != 0 {
                if let data = ptr!.pointee.ifa_data {
                    let stats = data.assumingMemoryBound(to: if_data.self).pointee
                    totalIn += UInt64(stats.ifi_ibytes)
                    totalOut += UInt64(stats.ifi_obytes)
                }
            }
            ptr = ptr!.pointee.ifa_next
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
}
