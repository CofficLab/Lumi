import Darwin
import Foundation
import IOKit.ps

/// 持有 Timer 的辅助类，避免 deinit（非隔离）访问 MainActor 隔离属性的问题。
private final class TimerHolder: @unchecked Sendable {
    var timer: Timer?

    func invalidate() {
        timer?.invalidate()
        timer = nil
    }
}

/// 设备信息数据模型
///
/// 采集并发布设备静态信息（设备名 / OS / 处理器 / 核心数）与动态指标
/// （CPU / 内存 / 磁盘 / 电池 / 运行时间）。
///
/// 简化版：不依赖外部日志库；数据采集逻辑内联于此。
@MainActor
public final class DeviceData: ObservableObject {

    // MARK: - Published Properties

    @Published public var cpuUsage: Double = 0.0
    @Published public var memoryUsage: Double = 0.0
    @Published public var memoryTotal: UInt64 = 0
    @Published public var memoryUsed: UInt64 = 0
    @Published public var diskTotal: Int64 = 0
    @Published public var diskUsed: Int64 = 0
    @Published public var batteryLevel: Double = 0.0
    @Published public var isCharging: Bool = false
    @Published public var uptime: TimeInterval = 0

    // MARK: - Static Properties

    public let deviceName: String
    public let osVersion: String
    public let processorName: String
    public let coreCount: Int

    // MARK: - Private Properties

    private nonisolated let timerHolder = TimerHolder()
    private var previousCPUTicks: (total: UInt64, idle: UInt64)?
    private var isMonitoring = false

    // MARK: - Initialization

    public init() {
        self.deviceName = Host.current().localizedName ?? "Unknown Mac"

        let os = ProcessInfo.processInfo.operatingSystemVersion
        self.osVersion = "macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"

        self.processorName = Self.getProcessorName()
        self.coreCount = Self.physicalCoreCount()

        self.memoryTotal = ProcessInfo.processInfo.physicalMemory

        updateDynamicData()
        startMonitoring()
    }

    deinit {
        timerHolder.invalidate()
        isMonitoring = false
    }

    // MARK: - Monitoring

    /// 开始周期性刷新动态指标（每 2 秒）。
    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateDynamicData()
            }
        }
        timerHolder.timer = timer
    }

    /// 停止刷新。
    public func stopMonitoring() {
        isMonitoring = false
        timerHolder.invalidate()
    }

    // MARK: - Data Fetching

    /// 刷新全部动态指标。
    public func updateDynamicData() {
        cpuUsage = Self.currentCPUUsage(previous: &previousCPUTicks)

        let memory = Self.getMemoryData()
        memoryUsed = memory.used
        memoryTotal = memory.total
        memoryUsage = memory.total > 0 ? Double(memory.used) / Double(memory.total) : 0

        let disk = Self.getDiskData()
        diskTotal = disk.total
        diskUsed = disk.used

        let battery = Self.getBatteryData()
        batteryLevel = battery.level
        isCharging = battery.isCharging

        uptime = ProcessInfo.processInfo.systemUptime
    }

    // MARK: - Helpers

    /// 物理 CPU 核心数（`hw.physicalcpu`）；失败时回退到逻辑核数。
    nonisolated static func physicalCoreCount() -> Int {
        var physicalCores: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("hw.physicalcpu", &physicalCores, &size, nil, 0) == 0, physicalCores > 0 {
            return Int(physicalCores)
        }
        return ProcessInfo.processInfo.activeProcessorCount
    }

    /// 处理器名称（`machdep.cpu.brand_string`）。
    nonisolated static func getProcessorName() -> String {
        var size: Int = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0 else {
            return ""
        }
        var model = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &model, &size, nil, 0) == 0 else {
            return ""
        }
        let bytes = model.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// 当前 CPU 使用率（0-100）：基于两次 `host_cpu_load_info` 采样差值。
    nonisolated static func currentCPUUsage(previous: inout (total: UInt64, idle: UInt64)?) -> Double {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let total = UInt64(info.cpu_ticks.0 + info.cpu_ticks.1 + info.cpu_ticks.2 + info.cpu_ticks.3)
        let idle = UInt64(info.cpu_ticks.3) // CPU_STATE_IDLE

        defer { previous = (total, idle) }
        guard let prev = previous, total >= prev.total, idle >= prev.idle else { return 0 }

        let totalDelta = total - prev.total
        let idleDelta = idle - prev.idle
        guard totalDelta > 0 else { return 0 }
        return Double(totalDelta - idleDelta) / Double(totalDelta) * 100
    }

    /// 内存数据（used = active + wired + compressed）。
    nonisolated static func getMemoryData() -> (used: UInt64, total: UInt64) {
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO, $0, &count)
            }
        }

        let total = ProcessInfo.processInfo.physicalMemory
        guard result == KERN_SUCCESS else { return (0, total) }

        let active = UInt64(stats.active_count) * UInt64(pageSize)
        let wired = UInt64(stats.wire_count) * UInt64(pageSize)
        let compressed = UInt64(stats.compressor_page_count) * UInt64(pageSize)
        return (active + wired + compressed, total)
    }

    /// 磁盘数据（根卷）。
    nonisolated static func getDiskData() -> (total: Int64, used: Int64) {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacity else {
            return (0, 0)
        }
        return (Int64(total), Int64(total - available))
    }

    /// 电池数据（无电池设备返回 level 0 / 非充电）。
    nonisolated static func getBatteryData() -> (level: Double, isCharging: Bool) {
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]

        guard let source = sources?.first else { return (0, false) }
        let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]

        let level: Double = if let current = description?[kIOPSCurrentCapacityKey] as? Int,
                               let max = description?[kIOPSMaxCapacityKey] as? Int, max > 0 {
            Double(current) / Double(max)
        } else { 0 }
        let isCharging = (description?[kIOPSIsChargingKey] as? Bool) ?? false

        return (level, isCharging)
    }
}
