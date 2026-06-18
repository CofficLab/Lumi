import AppKit
import Combine
import SwiftUI
import LumiCoreKit

/// 菜单栏内容视图（CPU 每核瞬时柱状图 + 内存单柱 + 电池指示器）
struct DeviceInfoMenuBarContentView: View {

    // MARK: - Properties

    @StateObject private var viewModel = DeviceInfoMenuBarContentViewModel()

    // MARK: - Body

    var body: some View {
        HStack(spacing: 4) {
            // CPU 柱状图
            Image(nsImage: viewModel.snapshot.cpuImage)
                .interpolation(.none)
                .help(viewModel.snapshot.cpuHelpText)

            // 内存柱状图
            Image(nsImage: viewModel.snapshot.memoryImage)
                .interpolation(.none)
                .help(viewModel.snapshot.memoryHelpText)

            // Battery indicator (only if device has battery)
            if viewModel.snapshot.showBattery {
                Image(nsImage: viewModel.snapshot.batteryImage)
                    .interpolation(.none)
                    .help(viewModel.snapshot.batteryHelpText)
            }
        }
    }
}

@MainActor
final class DeviceInfoMenuBarContentViewModel: ObservableObject {
    @Published private(set) var snapshot = DeviceInfoMenuBarSnapshot(metrics: .empty)

    private var cancellables = Set<AnyCancellable>()

    init() {
        startMonitoring()
    }

    deinit {
        Task { @MainActor in
            CPUService.shared.stopMonitoring()
            MemoryService.shared.stopMonitoring()
            BatteryService.shared.stopMonitoring()
        }
    }

    private func startMonitoring() {
        CPUService.shared.startMonitoring()
        MemoryService.shared.startMonitoring()
        BatteryService.shared.startMonitoring()

        let cpuMetrics = Publishers.CombineLatest3(
            CPUService.shared.$cpuUsage,
            CPUService.shared.$perCoreUsage,
            CPUService.shared.$loadAverage
        )
        .map { usage, perCoreUsage, _ in
            DeviceInfoMenuBarCPUMetrics(
                usagePercent: Int(usage.rounded()),
                perCoreUsagePercent: perCoreUsage.map { Int($0.rounded()) }
            )
        }

        let memoryMetrics = Publishers.CombineLatest3(
            MemoryService.shared.$memoryUsagePercentage,
            MemoryService.shared.$usedMemory,
            MemoryService.shared.$totalMemory
        )
        .map { usage, used, total in
            DeviceInfoMenuBarMemoryMetrics(
                usagePercent: Int(usage.rounded()),
                usedMemory: ByteCountFormatter.string(fromByteCount: Int64(used), countStyle: .memory),
                totalMemory: ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .memory)
            )
        }

        let batteryMetrics = Publishers.CombineLatest3(
            BatteryService.shared.$level,
            BatteryService.shared.$isCharging,
            BatteryService.shared.$hasBattery
        )
        .map { level, isCharging, hasBattery in
            DeviceInfoMenuBarBatteryMetrics(
                levelPercent: Int(level * 100),
                isCharging: isCharging,
                hasBattery: hasBattery
            )
        }

        cpuMetrics
            .combineLatest(memoryMetrics, batteryMetrics)
            .debounce(for: .milliseconds(80), scheduler: RunLoop.main)
            .map { DeviceInfoMenuBarMetrics(cpu: $0, memory: $1, battery: $2) }
            .removeDuplicates()
            .map(DeviceInfoMenuBarSnapshot.init(metrics:))
            .sink { [weak self] snapshot in
                self?.snapshot = snapshot
            }
            .store(in: &cancellables)
    }
}

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

struct DeviceInfoMenuBarBatteryMetrics: Equatable {
    var levelPercent: Int
    var isCharging: Bool
    var hasBattery: Bool
}

struct DeviceInfoMenuBarMetrics: Equatable {
    static let empty = DeviceInfoMenuBarMetrics(
        cpu: DeviceInfoMenuBarCPUMetrics(usagePercent: 0, perCoreUsagePercent: []),
        memory: DeviceInfoMenuBarMemoryMetrics(usagePercent: 0, usedMemory: "0 GB", totalMemory: "0 GB"),
        battery: DeviceInfoMenuBarBatteryMetrics(levelPercent: 0, isCharging: false, hasBattery: true)
    )

    var cpu: DeviceInfoMenuBarCPUMetrics
    var memory: DeviceInfoMenuBarMemoryMetrics
    var battery: DeviceInfoMenuBarBatteryMetrics
}

struct DeviceInfoMenuBarSnapshot {
    var cpuImage: NSImage
    var memoryImage: NSImage
    var batteryImage: NSImage
    var cpuHelpText: String
    var memoryHelpText: String
    var batteryHelpText: String
    var showBattery: Bool

    init(metrics: DeviceInfoMenuBarMetrics) {
        self.cpuImage = CPUMenuBarChartRenderer.makeImage(from: metrics.cpu.normalizedPerCoreUsage)
        self.memoryImage = MemoryMenuBarChartRenderer.makeImage(usage: Double(metrics.memory.usagePercent))
        self.batteryImage = BatteryMenuBarChartRenderer.makeImage(
            level: Double(metrics.battery.levelPercent) / 100.0,
            isCharging: metrics.battery.isCharging
        )
        self.cpuHelpText = Self.cpuHelpText(metrics.cpu)
        self.memoryHelpText = Self.memoryHelpText(metrics.memory)
        self.batteryHelpText = Self.batteryHelpText(metrics.battery)
        self.showBattery = metrics.battery.hasBattery
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

    private static func batteryHelpText(_ battery: DeviceInfoMenuBarBatteryMetrics) -> String {
        guard battery.hasBattery else { return "" }
        let charging = battery.isCharging ? " ⚡" : ""
        return String(format: LumiPluginLocalization.string("Battery %lld%%", bundle: .module), Int64(battery.levelPercent)) + charging
    }
}
