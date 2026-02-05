import Foundation
import Combine
import OSLog
import MagicKit

/// 内存监控服务
@MainActor
class MemoryService: ObservableObject, SuperLog {
    static let shared = MemoryService()
    nonisolated static let emoji = "💾"
    nonisolated static let verbose = false
    
    // MARK: - Published Properties
    
    /// 内存使用率 (0.0 - 100.0)
    @Published var memoryUsagePercentage: Double = 0.0
    
    /// 已用内存 (Bytes)
    @Published var usedMemory: UInt64 = 0
    
    /// 总内存 (Bytes)
    @Published var totalMemory: UInt64 = 0
    
    /// 内存压力 (Optional)
    @Published var memoryPressure: String = "Normal"
    
    // MARK: - Private Properties
    
    private var monitoringTimer: Timer?
    private var subscribersCount = 0
    
    private init() {
        self.totalMemory = ProcessInfo.processInfo.physicalMemory
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        subscribersCount += 1
        if monitoringTimer == nil {
            if Self.verbose {
                os_log("\(self.t)Starting Memory monitoring")
            }
            // Initial fetch
            updateMemoryUsage()

            monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateMemoryUsage()
                }
            }
        }
    }
    
    func stopMonitoring() {
        subscribersCount = max(0, subscribersCount - 1)
        if subscribersCount == 0 {
            if Self.verbose {
                os_log("\(self.t)Stopping Memory monitoring")
            }
            monitoringTimer?.invalidate()
            monitoringTimer = nil
        }
    }
    
    // MARK: - Private Methods

    /// 获取内核页面大小（使用系统 API 而非全局变量）
    private nonisolated func getKernelPageSize() -> UInt64 {
        // 使用 host_page_size API 而非直接访问全局变量
        var pageSize: vm_size_t = 0
        let result = host_page_size(mach_host_self(), &pageSize)
        return result == KERN_SUCCESS ? UInt64(pageSize) : 4096 // 默认 4KB
    }

    private func updateMemoryUsage() {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return }

        let pageSize = getKernelPageSize()
        
        // Activity Monitor logic approximation:
        // App Memory = Anonymous + Purgeable
        // Wired Memory = Wired
        // Compressed = Compressed
        // Used = App + Wired + Compressed
        
        // Using simpler "Used" definition:
        // Active + Wired (roughly)
        // Note: vm_stats.active_count includes file cache in some contexts, but usually 'active' pages are in RAM.
        // A safer "Used" for users is: Total - Free - Inactive (File Cache).
        
        // Let's go with:
        // Free = free_count + inactive_count + speculative_count
        // Used = Total - Free

        // let free = UInt64(vmStats.free_count) * pageSize
        // let inactive = UInt64(vmStats.inactive_count) * pageSize // Often considered "Available"/Cache
        // let active = UInt64(vmStats.active_count) * pageSize
        // let wired = UInt64(vmStats.wire_count) * pageSize
        // let compressed = UInt64(vmStats.compressor_page_count) * pageSize
        
        // "Available" memory usually includes Inactive.
        // So "Used" memory is Total - (Free + Inactive).
        // Wait, Inactive memory IS used by something (cache), but available for apps.
        // Activity Monitor shows "Memory Used".
        // Let's calculate "App Memory" + "Wired" + "Compressed".
        
        let active = UInt64(vmStats.active_count) * pageSize
        let wired = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count) * pageSize
        
        // Activity Monitor "Memory Used" = App Memory + Wired + Compressed
        // App Memory = (Internal - Purgeable) ... this gets complicated.
        
        // Simplified approach that matches most "Clean" tools:
        // Used = Active + Wired + Compressed
        let used = active + wired + compressed
        
        DispatchQueue.main.async {
            self.usedMemory = used
            self.memoryUsagePercentage = min(100.0, Double(used) / Double(self.totalMemory) * 100.0)
            
            // Memory Pressure (Heuristic based on free pages could be added, but simple usage is fine for now)
        }
    }
}
