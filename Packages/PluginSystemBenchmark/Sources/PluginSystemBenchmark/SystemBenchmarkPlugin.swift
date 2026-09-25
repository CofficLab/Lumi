import KernelCore
import ProviderSettingView
import SwiftUI

@MainActor
public final class SystemBenchmarkPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.system-benchmark"
    public let order = 7
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.system-benchmark",
        name: BenchmarkLocalization.string("System Benchmark"),
        description: BenchmarkLocalization.string("Measure local CPU, memory, and disk performance."),
        category: .system,
        stage: .stable,
        policy: .disabledByDefault
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([
            SettingEntryItem(
                id: id,
                title: BenchmarkLocalization.string("System Benchmark"),
                systemImage: "gauge.with.dots.needle.67percent",
                order: order
            ) {
                SystemBenchmarkSettingsView()
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: [id])
    }
}
