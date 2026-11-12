import Foundation

@MainActor
class MemoryManagerViewModel: ObservableObject {
    static let emoji = "💾"

    @Published var memoryUsagePercentage: Double = 0.0
    @Published var usedMemory: String = "0 GB"
    @Published var totalMemory: String = "0 GB"
    @Published var rawTotalMemory: UInt64 = 0
    @Published var topProcesses: [ProcessMetric] = []

    init() {}

    func apply(percentage: Double, used: UInt64, total: UInt64) {
        memoryUsagePercentage = percentage
        usedMemory = ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .memory)
        totalMemory = ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .memory)
        rawTotalMemory = total
    }

    func apply(topProcesses: [ProcessMetric]) {
        self.topProcesses = topProcesses
    }

    /// 主弹窗只展示前 5 条内存占用进程。
    var topProcessesPreview: [ProcessMetric] {
        Array(topProcesses.prefix(5))
    }
}
