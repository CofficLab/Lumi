import Combine
import Foundation
import MagicKit

/// Memory monitoring service
@MainActor
class MemoryService: ObservableObject, SuperLog {
    static let shared = MemoryService()
    nonisolated static let emoji = "💾"
    nonisolated static let verbose: Bool = false

    // MARK: - Published Properties

    /// Memory usage percentage (0.0 - 100.0)
    @Published var memoryUsagePercentage: Double = 0.0

    /// Used memory (Bytes)
    @Published var usedMemory: UInt64 = 0

    /// Total memory (Bytes)
    @Published var totalMemory: UInt64 = 0

    /// Memory pressure (Optional)
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
                DeviceInfoPlugin.logger.info("\(self.t) Starting Memory monitoring")
            }

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
                DeviceInfoPlugin.logger.info("\(self.t) Stopping Memory monitoring")
            }

            monitoringTimer?.invalidate()
            monitoringTimer = nil
        }
    }

    // MARK: - Private Methods

    private nonisolated func getKernelPageSize() -> UInt64 {
        var pageSize: vm_size_t = 0
        let result = host_page_size(mach_host_self(), &pageSize)
        return result == KERN_SUCCESS ? UInt64(pageSize) : 4096
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
        let active = UInt64(vmStats.active_count) * pageSize
        let wired = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count) * pageSize
        let used = active + wired + compressed

        DispatchQueue.main.async {
            self.usedMemory = used
            self.memoryUsagePercentage = min(100.0, Double(used) / Double(self.totalMemory) * 100.0)
        }
    }
}
