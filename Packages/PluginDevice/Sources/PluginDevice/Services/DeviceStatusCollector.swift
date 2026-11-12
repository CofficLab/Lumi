import Darwin
import Foundation
import LumiLoggingKit
import os

/// 设备状态采集服务。
///
/// 从插件既有的各采集服务（CPU / 内存 / GPU / 电池 / 存储 / 温度 / 进程）
/// 读取当前快照，按查询范围裁剪成一份 `DeviceStatusPayload`。
///
/// ## 为什么不自己重新采样
///
/// 插件的采集服务都是引用计数的常驻服务：`DeviceMetricsObserver` 启动它们、
/// 插件关闭时停止。重新采样会绕开这套生命周期（重复起定时器、拿不到首帧数据），
/// 而且温度采集走的是 IOKit 私有 HID API，重复调用代价高。
/// 直接读已发布的状态既便宜又与主界面显示的口径一致。
///
/// ## 进程数据的例外
///
/// `ProcessService.topProcesses` 只在**进程采样轮次**里更新，且采样周期是 1 秒。
/// 为了让「问一次进程」能立刻拿到数据，这里在需要时主动触发一次采样。
@MainActor
final class DeviceStatusCollector {

    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.device-info",
        category: "DeviceStatusCollector"
    )

    /// 卡片上展示的进程条数上限。
    static let processLimit = 8

    init() {}

    // MARK: - Public Methods

    /// 按范围采集一份设备状态快照。
    ///
    /// - Parameter scope: 查询范围。
    /// - Returns: 结构化载荷。
    func collect(scope: DeviceStatusScope) -> DeviceStatusPayload {
        DeviceStatusPayload(
            scope: scope,
            timestamp: Date().timeIntervalSince1970,
            device: identity(),
            cpu: scope == .cpu || scope == .overview ? cpuStatus() : nil,
            memory: scope == .memory || scope == .overview ? memoryStatus() : nil,
            gpu: scope == .overview ? gpuStatus() : nil,
            battery: scope == .overview ? batteryStatus() : nil,
            volumes: scope == .storage || scope == .overview ? volumeStatuses() : [],
            thermal: scope == .thermal ? thermalStatus() : nil,
            processes: scope.needsProcesses ? processStatuses() : []
        )
    }

    // MARK: - Collectors

    /// 设备身份信息。
    private func identity() -> DeviceIdentity {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return DeviceIdentity(
            name: Host.current().localizedName ?? "Unknown Mac",
            osVersion: "macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            processorName: processorName(),
            physicalCoreCount: DeviceData.physicalCoreCount(),
            logicalCoreCount: ProcessInfo.processInfo.activeProcessorCount,
            uptime: ProcessInfo.processInfo.systemUptime
        )
    }

    /// 处理器型号。
    private func processorName() -> String {
        var size = 0
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

    /// CPU 快照。
    private func cpuStatus() -> DeviceCPUStatus {
        let service = CPUService.shared
        return DeviceCPUStatus(
            usagePercentage: service.cpuUsage,
            perCoreUsage: service.perCoreUsage,
            loadAverage: service.loadAverage,
            userPercentage: service.userUsage,
            systemPercentage: service.systemUsage,
            idlePercentage: service.idleUsage
        )
    }

    /// 内存快照。
    private func memoryStatus() -> DeviceMemoryStatus {
        let service = MemoryService.shared
        return DeviceMemoryStatus(
            usagePercentage: service.memoryUsagePercentage,
            usedBytes: service.usedMemory,
            totalBytes: service.totalMemory,
            pressure: service.memoryPressure
        )
    }

    /// GPU 快照。
    private func gpuStatus() -> DeviceGPUStatus {
        let service = GPUService.shared
        return DeviceGPUStatus(
            utilizationPercentage: service.utilization,
            usedMemoryBytes: service.usedMemory,
            totalMemoryBytes: service.totalMemory,
            temperatureCelsius: service.temperature,
            modelName: service.modelName
        )
    }

    /// 电池快照。
    private func batteryStatus() -> DeviceBatteryStatus {
        let service = BatteryService.shared
        return DeviceBatteryStatus(
            level: service.level,
            isCharging: service.isCharging,
            isCharged: service.isCharged,
            healthPercentage: service.healthPercentage,
            cycleCount: service.cycleCount,
            temperatureCelsius: service.temperature,
            watts: service.watts,
            hasBattery: service.hasBattery
        )
    }

    /// 磁盘卷快照。
    private func volumeStatuses() -> [DeviceVolumeStatus] {
        let service = StorageService.shared
        var volumes: [DeviceVolumeStatus] = []
        if let root = service.rootVolume {
            volumes.append(Self.volumeStatus(from: root))
        }
        volumes.append(contentsOf: service.externalVolumes.map(Self.volumeStatus(from:)))
        return volumes
    }

    /// 把 `VolumeInfo` 转成载荷里的卷状态。
    private static func volumeStatus(from volume: VolumeInfo) -> DeviceVolumeStatus {
        DeviceVolumeStatus(
            name: volume.name,
            totalBytes: volume.totalCapacity,
            availableBytes: volume.availableCapacity,
            isInternal: volume.isInternal,
            isEjectable: volume.isEjectable
        )
    }

    /// 温度快照。
    private func thermalStatus() -> DeviceThermalStatus {
        let service = ThermalService.shared
        return DeviceThermalStatus(
            readings: service.readings.map {
                DeviceThermalReading(index: $0.index, kind: $0.kind?.rawValue, celsius: $0.celsius)
            },
            peakCelsius: service.peakCelsius
        )
    }

    /// 进程快照。
    ///
    /// `ProcessService` 每秒采样一次，刚启动时可能还没有数据。
    /// 这里在列表为空时主动触发一次采样，让「问一次进程」不必等下一秒。
    /// `sampleProcessesInternal()` 直接返回本轮结果，不写 `topProcesses`，
    /// 因此必须用返回值而不是再读一次 published 属性。
    private func processStatuses() -> [DeviceProcessStatus] {
        let service = ProcessService.shared
        let metrics = service.topProcesses.isEmpty
            ? service.sampleProcessesInternal()
            : service.topProcesses

        let byCPU = metrics.sorted { $0.cpuUsage > $1.cpuUsage }
        let byMemory = metrics.sorted { $0.memoryUsage > $1.memoryUsage }
        // 两个榜单合并去重：CPU 榜与内存榜通常高度重合，
        // 直接拼接会让同一进程出现两次。
        var seen = Set<Int32>()
        var merged: [DeviceProcessStatus] = []
        for metric in byCPU + byMemory {
            guard !seen.contains(metric.id) else { continue }
            seen.insert(metric.id)
            merged.append(
                DeviceProcessStatus(
                    pid: metric.id,
                    name: metric.name,
                    cpuPercentage: metric.cpuUsage,
                    memoryBytes: metric.memoryUsage,
                    instanceCount: metric.instanceCount,
                    isCurrentApp: metric.isCurrentApp
                )
            )
            if merged.count >= Self.processLimit { break }
        }
        return merged
    }
}
