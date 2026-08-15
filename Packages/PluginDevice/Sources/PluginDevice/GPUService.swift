import Combine
import Foundation
import IOKit
import os
import SuperLogKit

/// GPU monitoring service that reads utilization, memory, and temperature
/// from IOKit `IOAccelerator` services on Apple Silicon / Intel Macs.
@MainActor
public final class GPUService: ObservableObject, SuperLog {
    public static let shared = GPUService()
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "devicemonitor.gpu")
    nonisolated public static let emoji = "🎮"
    nonisolated(unsafe) static var verbose: Bool = false

    // MARK: - Published Properties

    /// Current GPU device utilization (0–100).
    @Published public var utilization: Double = 0
    /// Renderer utilization (0–100). `nil` when unavailable.
    @Published public var rendererUtilization: Double = 0
    /// Tiler utilization (0–100). `nil` when unavailable.
    @Published public var tilerUtilization: Double = 0
    /// GPU memory currently in use (bytes).
    @Published public var usedMemory: UInt64 = 0
    /// Total GPU memory allocated (bytes).
    @Published public var totalMemory: UInt64 = 0
    /// GPU temperature in Celsius. `0` when unavailable.
    @Published public var temperature: Double = 0
    /// GPU model name.
    @Published public var modelName: String = ""

    // MARK: - Private Properties

    private var monitoringTimer: Timer?
    private var samplingTask: Task<Void, Never>?
    private var subscribersCount = 0

    package init() {}

    // MARK: - Public Methods

    public func startMonitoring() {
        subscribersCount += 1
        if monitoringTimer == nil {
            if Self.verbose {
                Self.logger.info("\(Self.t)\(Self.emoji) 开始 GPU 监控")
            }
            sampleGPU()

            monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.sampleGPU()
                }
            }
        }
    }

    public func stopMonitoring() {
        subscribersCount = max(0, subscribersCount - 1)
        if subscribersCount == 0 {
            if Self.verbose {
                Self.logger.info("\(Self.t)\(Self.emoji) 停止 GPU 监控")
            }
            monitoringTimer?.invalidate()
            monitoringTimer = nil
            samplingTask?.cancel()
            samplingTask = nil
        }
    }

    // MARK: - Convenience

    /// Formatted used memory string (e.g. "3.2 GB").
    public var usedMemoryString: String {
        ByteCountFormatter.string(fromByteCount: Int64(usedMemory), countStyle: .memory)
    }

    /// Formatted total memory string (e.g. "8 GB").
    public var totalMemoryString: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalMemory), countStyle: .memory)
    }

    /// Memory usage percentage (0–100).
    public var memoryUsagePercentage: Double {
        guard totalMemory > 0 else { return 0 }
        return Double(usedMemory) / Double(totalMemory) * 100.0
    }

    // MARK: - Sampling

    private func sampleGPU() {
        guard samplingTask == nil else { return }

        samplingTask = Task.detached(priority: .utility) {
            let reading = Self.readGPU()

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.samplingTask = nil
                guard self.subscribersCount > 0 else { return }

                self.utilization = reading.utilization
                self.rendererUtilization = reading.rendererUtilization
                self.tilerUtilization = reading.tilerUtilization
                self.usedMemory = reading.usedMemory
                self.totalMemory = reading.totalMemory
                self.temperature = reading.temperature
                self.modelName = reading.modelName
            }
        }
    }

    // MARK: - IOKit Reading (nonisolated)

    private nonisolated static func readGPU() -> GPUReading {
        let accelerators = acceleratorServices()
        guard !accelerators.isEmpty else {
            return .empty
        }
        defer {
            accelerators.forEach { IOObjectRelease($0) }
        }

        var best: GPUReading?
        for accelerator in accelerators {
            guard let stats = registryDictionary(accelerator, "PerformanceStatistics") else {
                continue
            }

            let utilization = doubleFromAny(stats["Device Utilization %"])
                ?? doubleFromAny(stats["GPU Activity(%)"])
                ?? 0
            let renderer = doubleFromAny(stats["Renderer Utilization %"]) ?? 0
            let tiler = doubleFromAny(stats["Tiler Utilization %"]) ?? 0
            let temp = doubleFromAny(stats["Temperature(C)"]) ?? 0
            let used = uint64FromAny(stats["In use system memory"])
            let allocated = uint64FromAny(stats["Alloc system memory"])
            let model = registryString(accelerator, "model")
                ?? registryString(accelerator, "IOClass")
                ?? "GPU"

            let reading = GPUReading(
                utilization: utilization,
                rendererUtilization: renderer,
                tilerUtilization: tiler,
                usedMemory: used,
                totalMemory: allocated,
                temperature: temp,
                modelName: model
            )

            if best == nil || reading.utilization > best!.utilization {
                best = reading
            }
        }

        return best ?? .empty
    }

    // MARK: - IOKit Helpers

    private nonisolated static func acceleratorServices() -> [io_service_t] {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOAccelerator"),
            &iterator
        )
        guard result == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var services: [io_service_t] = []
        while true {
            let service = IOIteratorNext(iterator)
            guard service != IO_OBJECT_NULL else { break }
            services.append(service)
        }
        return services
    }

    private nonisolated static func registryDictionary(
        _ service: io_service_t,
        _ key: String
    ) -> [String: Any]? {
        guard let cfDict = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        return cfDict
    }

    private nonisolated static func registryString(
        _ service: io_service_t,
        _ key: String
    ) -> String? {
        guard let cfStr = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String else {
            return nil
        }
        return cfStr
    }

    private nonisolated static func doubleFromAny(_ value: Any?) -> Double? {
        switch value {
        case let v as Double: return v
        case let v as Float: return Double(v)
        case let v as Int: return Double(v)
        case let v as Int64: return Double(v)
        case let v as UInt64: return Double(v)
        case let v as NSNumber: return v.doubleValue
        default: return nil
        }
    }

    private nonisolated static func uint64FromAny(_ value: Any?) -> UInt64 {
        switch value {
        case let v as UInt64: return v
        case let v as Int64: return UInt64(v)
        case let v as Int: return UInt64(v)
        case let v as NSNumber: return v.uint64Value
        default: return 0
        }
    }
}
