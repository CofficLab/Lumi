import AppKit
import Combine
import SwiftUI
import SuperLogKit
import os

/// 菜单栏内容视图（CPU 每核瞬时柱状图 + 内存单柱）
public struct DeviceInfoMenuBarContentView: View {

    // MARK: - Properties

    // 共享 ViewModel 保证 CPU/内存指标持续更新。
    @ObservedObject private var viewModel = DeviceInfoMenuBarContentViewModel.shared

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
        }
    }
}

@MainActor
final class DeviceInfoMenuBarContentViewModel: ObservableObject, SuperLog {
    static let shared = DeviceInfoMenuBarContentViewModel()

    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "devicemenubar.view")
    nonisolated public static let emoji = "📊"
    nonisolated(unsafe) static var verbose: Bool = false

    @Published private(set) var snapshot = DeviceInfoMenuBarSnapshot(metrics: .empty)

    private var lastMetrics = DeviceInfoMenuBarMetrics.empty
    private var cancellables = Set<AnyCancellable>()

    /// 心跳节流计数：Combine sink 每触发一次自增，每 N 次打一条日志，
    /// 避免每秒 12 条心跳刷屏。用于排查 CPU 占用持续 100% 时确认本链路是否在狂跑。
    private var sinkTickCount = 0
    private let sinkTickLogEvery = 10

    private init() {
        if Self.verbose { Self.logger.info("\(Self.t)ViewModel init，启动监控") }
        startMonitoring()
        observeMenuBarAppearanceChanges()
    }

    private func observeMenuBarAppearanceChanges() {
        NotificationCenter.default.publisher(for: .lumiMenuBarAppearanceDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self else { return }
                if Self.verbose { Self.logger.info("\(self.t)收到外观变更通知，刷新快照") }
                if let button = notification.object as? NSStatusBarButton {
                    let appearance = button.window?.effectiveAppearance ?? button.effectiveAppearance
                    appearance.performAsCurrentDrawingAppearance {
                        self.refreshSnapshotForCurrentAppearance()
                    }
                } else {
                    self.refreshSnapshotForCurrentAppearance()
                }
            }
            .store(in: &cancellables)
    }

    func refreshSnapshotForCurrentAppearance() {
        snapshot = DeviceInfoMenuBarSnapshot(metrics: lastMetrics)
    }

    private func startMonitoring() {
        CPUService.shared.startMonitoring()
        MemoryService.shared.startMonitoring()
        if Self.verbose { Self.logger.info("\(Self.t)订阅 CPU/Memory 发布者，启动 Combine 链(debounce 80ms)") }

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

        cpuMetrics
            .combineLatest(memoryMetrics)
            .debounce(for: .milliseconds(80), scheduler: RunLoop.main)
            .map { DeviceInfoMenuBarMetrics(cpu: $0, memory: $1) }
            .removeDuplicates()
            .sink { [weak self] metrics in
                guard let self else { return }
                self.lastMetrics = metrics
                self.snapshot = DeviceInfoMenuBarSnapshot(metrics: metrics)
                // 节流心跳：每 N 次重绘打一条，确认本链路是否持续在重生成 NSImage。
                // 若这里高频触发，说明上游 CPU/Memory 发布者在持续推送，是 100% CPU 的直接信号。
                self.sinkTickCount += 1
                if Self.verbose, self.sinkTickCount % self.sinkTickLogEvery == 0 {
                    Self.logger.info("\(self.t)tick #\(self.sinkTickCount) 刷新快照，cpu=\(metrics.cpu.usagePercent)%，mem=\(metrics.memory.usagePercent)%")
                }
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
