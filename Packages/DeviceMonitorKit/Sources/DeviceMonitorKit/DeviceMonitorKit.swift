// DeviceMonitorKit
// A Swift package for monitoring macOS system metrics including CPU, memory,
// network, disk, and process usage.

// MARK: - Public API

/// The primary namespace for DeviceMonitorKit.
public enum DeviceMonitorKit {
    /// Convenience accessors for shared services.
    @MainActor
    public static var cpu: CPUService { CPUService.shared }
    @MainActor
    public static var memory: MemoryService { MemoryService.shared }
    @MainActor
    public static var process: ProcessService { ProcessService.shared }
    @MainActor
    public static var systemMonitor: SystemMonitorService { SystemMonitorService.shared }
    @MainActor
    public static var cpuHistory: CPUHistoryService { CPUHistoryService.shared }
    @MainActor
    public static var memoryHistory: MemoryHistoryService { MemoryHistoryService.shared }
}
