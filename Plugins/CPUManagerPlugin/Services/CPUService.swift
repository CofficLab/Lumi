import Foundation
import Combine
import OSLog
import MagicKit

/// CPU 监控服务：提供实时 CPU 使用率
@MainActor
class CPUService: ObservableObject, SuperLog {
    static let shared = CPUService()
    static let emoji = "🧠"
    static let verbose = false
    
    // MARK: - Published Properties
    
    /// 当前总 CPU 使用率 (0.0 - 100.0)
    @Published var cpuUsage: Double = 0.0
    
    /// 系统负载 (1m, 5m, 15m)
    @Published var loadAverage: [Double] = [0, 0, 0]
    
    // MARK: - Private Properties
    
    private var monitoringTimer: Timer?
    private var subscribersCount = 0
    
    // CPU Calculation State
    private var previousInfo = processor_info_array_t(nil)
    private var previousCount = mach_msg_type_number_t(0)
    
    private init() {}
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        subscribersCount += 1
        if monitoringTimer == nil {
            if Self.verbose {
                os_log("\(self.t)Starting CPU monitoring")
            }
            // Initial fetch
            updateCPUUsage()
            
            monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.updateCPUUsage()
            }
        }
    }
    
    func stopMonitoring() {
        subscribersCount = max(0, subscribersCount - 1)
        if subscribersCount == 0 {
            if Self.verbose {
                os_log("\(self.t)Stopping CPU monitoring")
            }
            monitoringTimer?.invalidate()
            monitoringTimer = nil
            
            // Cleanup mach memory
            if let prevInfo = previousInfo {
                let prevSize = Int(previousCount) * MemoryLayout<integer_t>.stride
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevInfo), vm_size_t(prevSize))
                previousInfo = nil
                previousCount = 0
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func updateCPUUsage() {
        let usage = calculateCPUUsage()
        let load = getLoadAverage()
        
        DispatchQueue.main.async {
            self.cpuUsage = usage
            self.loadAverage = load
        }
    }
    
    private func calculateCPUUsage() -> Double {
        var processorInfo = processor_info_array_t(nil)
        var processorMsgCount = mach_msg_type_number_t(0)
        var processorCount = natural_t(0)
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &processorCount, &processorInfo, &processorMsgCount)
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        var totalUsage = 0.0
        
        if let prevInfo = previousInfo {
            var inUse: Int32 = 0
            var total: Int32 = 0
            
            for i in 0..<Int(processorCount) {
                let base = i * Int(CPU_STATE_MAX)
                
                let user = processorInfo![base + Int(CPU_STATE_USER)] - prevInfo[base + Int(CPU_STATE_USER)]
                let system = processorInfo![base + Int(CPU_STATE_SYSTEM)] - prevInfo[base + Int(CPU_STATE_SYSTEM)]
                let nice = processorInfo![base + Int(CPU_STATE_NICE)] - prevInfo[base + Int(CPU_STATE_NICE)]
                let idle = processorInfo![base + Int(CPU_STATE_IDLE)] - prevInfo[base + Int(CPU_STATE_IDLE)]
                
                inUse += user + system + nice
                total += user + system + nice + idle
            }
            
            // Deallocate previous info
            let prevSize = Int(previousCount) * MemoryLayout<integer_t>.stride
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevInfo), vm_size_t(prevSize))
            
            if total > 0 {
                totalUsage = Double(inUse) / Double(total) * 100.0
            }
        }
        
        // Update previous info
        previousInfo = processorInfo
        previousCount = processorMsgCount
        
        return totalUsage
    }
    
    private func getLoadAverage() -> [Double] {
        var loadAvg = [Double](repeating: 0.0, count: 3)
        var samples = [Double](repeating: 0.0, count: 3)
        
        if getloadavg(&samples, 3) == 3 {
            loadAvg = samples
        }
        
        return loadAvg
    }
}
