import AppKit
import Combine
import os
import KitSuperLog
import SwiftUI

/// 菜单栏 CPU/内存指标的共享 ViewModel。
///
/// 单例模式：CPU/内存柱状图持续更新由本 ViewModel 驱动，
/// 订阅 `CPUService` / `MemoryService` 的发布者，经 80ms 防抖后
/// 生成 `DeviceInfoMenuBarSnapshot`（内含预渲染的 NSImage）。
@MainActor
final class DeviceInfoMenuBarContentViewModel: ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "devicemenubar.view")
    nonisolated public static let emoji = "📊"
    nonisolated(unsafe) static var verbose: Bool = false

    @Published private(set) var snapshot = DeviceInfoMenuBarSnapshot(metrics: .empty)

    private var lastMetrics = DeviceInfoMenuBarMetrics.empty

    /// 心跳节流计数：Combine sink 每触发一次自增，每 N 次打一条日志，
    /// 避免每秒 12 条心跳刷屏。用于排查 CPU 占用持续 100% 时确认本链路是否在狂跑。
    init() {}

    func refreshSnapshotForCurrentAppearance() {
        snapshot = DeviceInfoMenuBarSnapshot(metrics: lastMetrics)
    }

    func applyCPU(usage: Double, perCoreUsage: [Double]) {
        updateMetrics(
            cpu: DeviceInfoMenuBarCPUMetrics(
                usagePercent: Int(usage.rounded()),
                perCoreUsagePercent: perCoreUsage.map { Int($0.rounded()) }
            ),
            memory: lastMetrics.memory
        )
    }

    func applyMemory(percentage: Double, used: UInt64, total: UInt64) {
        updateMetrics(
            cpu: lastMetrics.cpu,
            memory: DeviceInfoMenuBarMemoryMetrics(
                usagePercent: Int(percentage.rounded()),
                usedMemory: ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .memory),
                totalMemory: ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .memory)
            )
        )
    }

    private func updateMetrics(cpu: DeviceInfoMenuBarCPUMetrics, memory: DeviceInfoMenuBarMemoryMetrics) {
        let metrics = DeviceInfoMenuBarMetrics(cpu: cpu, memory: memory)
        guard metrics != lastMetrics else { return }
        lastMetrics = metrics
        snapshot = DeviceInfoMenuBarSnapshot(metrics: metrics)
    }
}

// MARK: - 菜单栏指标模型

struct DeviceInfoMenuBarCPUMetrics: Equatable {
    var usagePercent: Int
    var perCoreUsagePercent: [Int]

    var normalizedPerCoreUsage: [Double] {
        perCoreUsagePercent.map(Double.init)
    }
}

struct DeviceInfoMenuBarMemoryMetrics: Equatable {
    var usagePercent: Int
    var usedMemory: String
    var totalMemory: String
}

struct DeviceInfoMenuBarMetrics: Equatable {
    static let empty = DeviceInfoMenuBarMetrics(
        cpu: DeviceInfoMenuBarCPUMetrics(usagePercent: 0, perCoreUsagePercent: []),
        memory: DeviceInfoMenuBarMemoryMetrics(usagePercent: 0, usedMemory: "0 GB", totalMemory: "0 GB")
    )

    var cpu: DeviceInfoMenuBarCPUMetrics
    var memory: DeviceInfoMenuBarMemoryMetrics
}

struct DeviceInfoMenuBarSnapshot {
    var cpuImage: NSImage
    var memoryImage: NSImage
    var cpuHelpText: String
    var memoryHelpText: String

    init(metrics: DeviceInfoMenuBarMetrics) {
        self.cpuImage = CPUMenuBarChartRenderer.makeImage(from: metrics.cpu.normalizedPerCoreUsage)
        self.memoryImage = MemoryMenuBarChartRenderer.makeImage(usage: Double(metrics.memory.usagePercent))
        self.cpuHelpText = Self.cpuHelpText(metrics.cpu)
        self.memoryHelpText = Self.memoryHelpText(metrics.memory)
    }

    private static func cpuHelpText(_ cpu: DeviceInfoMenuBarCPUMetrics) -> String {
        let coreCount = cpu.perCoreUsagePercent.count
        if coreCount > 0 {
            return String(format: LumiPluginLocalization.string("CPU %.0f%% · %d Cores", bundle: .module), Double(cpu.usagePercent), coreCount)
        } else {
            return String(format: LumiPluginLocalization.string("CPU %.0f%%", bundle: .module), Double(cpu.usagePercent))
        }
    }

    private static func memoryHelpText(_ memory: DeviceInfoMenuBarMemoryMetrics) -> String {
        String(format: LumiPluginLocalization.string("Memory %lld%% · %@ / %@", bundle: .module), Int64(memory.usagePercent), memory.usedMemory, memory.totalMemory)
    }
}
